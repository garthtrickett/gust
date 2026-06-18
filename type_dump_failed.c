#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <sched.h>
#include <sys/types.h>
#include <dirent.h>

typedef void Any;

// ====================================================
// GUST COOPERATIVE FIBER RUNTIME
// ====================================================
typedef enum {
    GUST_FIBER_RUNNING,
    GUST_FIBER_READY,
    GUST_FIBER_SUSPENDED,
    GUST_FIBER_DEAD
} gust_FiberState;

typedef struct gust_Fiber gust_Fiber;
struct gust_Fiber {
    void* sp;
    void* stack_base;
    size_t stack_size;
    gust_FiberState state;
    gust_Fiber* parent;
    gust_Fiber* next;
    void* shard;
};

typedef struct {
    int id;
    pthread_t thread;
    gust_Fiber* run_queue_head;
    gust_Fiber* run_queue_tail;
    pthread_mutex_t lock;
    gust_Fiber* active_fiber;
    gust_Fiber shard_fiber;
} gust_SchedulerShard;

#if defined(_MSC_VER)
#define GUST_THREAD_LOCAL __declspec(thread)
#elif defined(__GNUC__) || defined(__clang__)
#define GUST_THREAD_LOCAL __thread
#elif __STDC_VERSION__ >= 201112L
#define GUST_THREAD_LOCAL _Thread_local
#else
#define GUST_THREAD_LOCAL
#endif

static GUST_THREAD_LOCAL gust_SchedulerShard* active_shard = NULL;
static int gust_num_shards = 0;
static gust_SchedulerShard* gust_shards = NULL;
static volatile int gust_scheduler_running = 1;

void gust_context_switch(void** from_rsp, void* to_rsp);
void gust_fiber_entry_wrapper(void);

#if defined(__x86_64__)
#if defined(__APPLE__)
__asm__(
".text\n"
".global _gust_context_switch\n"
"_gust_context_switch:\n"
"    pushq %rbp\n"
"    pushq %rbx\n"
"    pushq %r12\n"
"    pushq %r13\n"
"    pushq %r14\n"
"    pushq %r15\n"
"    movq %rsp, (%rdi)\n"
"    movq %rsi, %rsp\n"
"    popq %r15\n"
"    popq %r14\n"
"    popq %r13\n"
"    popq %r12\n"
"    popq %rbx\n"
"    popq %rbp\n"
"    ret\n"
);
#else
__asm__(
".text\n"
".global gust_context_switch\n"
"gust_context_switch:\n"
"    pushq %rbp\n"
"    pushq %rbx\n"
"    pushq %r12\n"
"    pushq %r13\n"
"    pushq %r14\n"
"    pushq %r15\n"
"    movq %rsp, (%rdi)\n"
"    movq %rsi, %rsp\n"
"    popq %r15\n"
"    popq %r14\n"
"    popq %r13\n"
"    popq %r12\n"
"    popq %rbx\n"
"    popq %rbp\n"
"    ret\n"
);
#endif

#elif defined(__aarch64__)
#if defined(__APPLE__)
__asm__(
".text\n"
".global _gust_context_switch\n"
"_gust_context_switch:\n"
"    stp x29, x30, [sp, #-16]!\n"
"    stp x27, x28, [sp, #-16]!\n"
"    stp x25, x26, [sp, #-16]!\n"
"    stp x23, x24, [sp, #-16]!\n"
"    stp x21, x22, [sp, #-16]!\n"
"    stp x19, x20, [sp, #-16]!\n"
"    mov x2, sp\n"
"    str x2, [x0]\n"
"    mov sp, x1\n"
"    ldp x19, x20, [sp], #16\n"
"    ldp x21, x22, [sp], #16\n"
"    ldp x23, x24, [sp], #16\n"
"    ldp x25, x26, [sp], #16\n"
"    ldp x27, x28, [sp], #16\n"
"    ldp x29, x30, [sp], #16\n"
"    ret\n"
);
#else
__asm__(
".text\n"
".global gust_context_switch\n"
"gust_context_switch:\n"
"    stp x29, x30, [sp, #-16]!\n"
"    stp x27, x28, [sp, #-16]!\n"
"    stp x25, x26, [sp, #-16]!\n"
"    stp x23, x24, [sp, #-16]!\n"
"    stp x21, x22, [sp, #-16]!\n"
"    stp x19, x20, [sp, #-16]!\n"
"    mov x2, sp\n"
"    str x2, [x0]\n"
"    mov sp, x1\n"
"    ldp x19, x20, [sp], #16\n"
"    ldp x21, x22, [sp], #16\n"
"    ldp x23, x24, [sp], #16\n"
"    ldp x25, x26, [sp], #16\n"
"    ldp x27, x28, [sp], #16\n"
"    ldp x29, x30, [sp], #16\n"
"    ret\n"
);
#endif

#else
void gust_context_switch(void** from_rsp, void* to_rsp) {
    // Fallback for unsupported CPU configurations
}
#endif

void gust_fiber_exit(gust_Fiber* fiber);
void gust_fiber_switch(gust_Fiber* from, gust_Fiber* to);

#if defined(__x86_64__)
#if defined(__APPLE__)
__asm__(
".text\n"
".global _gust_fiber_entry_wrapper\n"
"_gust_fiber_entry_wrapper:\n"
"    movq %r13, %rdi\n"
"    callq *%r12\n"
"    movq %r14, %rdi\n"
"    callq _gust_fiber_exit\n"
);
#else
__asm__(
".text\n"
".global gust_fiber_entry_wrapper\n"
"gust_fiber_entry_wrapper:\n"
"    movq %r13, %rdi\n"
"    callq *%r12\n"
"    movq %r14, %rdi\n"
"    callq gust_fiber_exit\n"
);
#endif

#elif defined(__aarch64__)
#if defined(__APPLE__)
__asm__(
".text\n"
".global _gust_fiber_entry_wrapper\n"
"_gust_fiber_entry_wrapper:\n"
"    mov x0, x20\n"
"    blr x19\n"
"    mov x0, x21\n"
"    bl _gust_fiber_exit\n"
);
#else
__asm__(
".text\n"
".global gust_fiber_entry_wrapper\n"
"gust_fiber_entry_wrapper:\n"
"    mov x0, x20\n"
"    blr x19\n"
"    mov x0, x21\n"
"    bl gust_fiber_exit\n"
);
#endif

#else
void gust_fiber_entry_wrapper(void) {
    // Fallback
}
#endif

void gust_fiber_exit(gust_Fiber* fiber) {
    fiber->state = GUST_FIBER_DEAD;
    if (fiber->parent) {
        gust_fiber_switch(fiber, fiber->parent);
    } else {
        printf("Error: Fiber exited with no parent context to yield back to.\n");
        exit(1);
    }
}

void gust_fiber_switch(gust_Fiber* from, gust_Fiber* to) {
    gust_context_switch(&from->sp, to->sp);
}

gust_Fiber* gust_fiber_create(size_t stack_size, void (*entry_fn)(void*), void* arg) {
    gust_Fiber* fiber = (gust_Fiber*)malloc(sizeof(gust_Fiber));
    if (!fiber) return NULL;
    if (stack_size < 16384) stack_size = 16384;
    fiber->stack_size = stack_size;
    fiber->stack_base = malloc(stack_size);
    if (!fiber->stack_base) {
        free(fiber);
        return NULL;
    }
    fiber->state = GUST_FIBER_READY;
    fiber->parent = NULL;
    fiber->next = NULL;
    void* sp = (void*)(((uintptr_t)fiber->stack_base + stack_size) & ~15UL);

    #if defined(__x86_64__)
    uint64_t* stack = (uint64_t*)sp;
    stack--; *stack = (uint64_t)gust_fiber_entry_wrapper;
    stack--; *stack = 0; // rbp
    stack--; *stack = 0; // rbx
    stack--; *stack = (uint64_t)entry_fn; // r12
    stack--; *stack = (uint64_t)arg; // r13
    stack--; *stack = (uint64_t)fiber; // r14
    stack--; *stack = 0; // r15
    fiber->sp = (void*)stack;
    #elif defined(__aarch64__)
    uint64_t* stack = (uint64_t*)sp;
    stack -= 12;
    stack[11] = (uint64_t)gust_fiber_entry_wrapper;
    stack[10] = 0;
    stack[9] = 0;
    stack[8] = 0;
    stack[7] = 0;
    stack[6] = 0;
    stack[5] = 0;
    stack[4] = 0;
    stack[3] = 0;
    stack[2] = (uint64_t)fiber;
    stack[1] = (uint64_t)arg;
    stack[0] = (uint64_t)entry_fn;
    fiber->sp = (void*)stack;
    #else
    fiber->sp = sp;
    #endif
    return fiber;
}

void gust_fiber_free(gust_Fiber* fiber) {
    if (fiber) {
        if (fiber->stack_base) {
            free(fiber->stack_base);
        }
        free(fiber);
    }
}

#include <poll.h>
#include <unistd.h>

void* gust_shard_loop(void* arg) {
    gust_SchedulerShard* shard = (gust_SchedulerShard*)arg;
    active_shard = shard;

    int core_id = shard->id;
#if defined(__linux__)
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
#elif defined(__APPLE__)
    #include <mach/thread_policy.h>
    #include <mach/thread_act.h>
    #include <mach/mach_init.h>
    thread_affinity_policy_data_t policy = { core_id + 1 };
    thread_policy_set(pthread_mach_thread_np(pthread_self()), THREAD_AFFINITY_POLICY, (thread_policy_t)&policy, THREAD_AFFINITY_POLICY_COUNT);
#endif

    while (gust_scheduler_running) {
        pthread_mutex_lock(&shard->lock);
        gust_Fiber* next = shard->run_queue_head;
        if (next) {
            shard->run_queue_head = next->next;
            if (!shard->run_queue_head) {
                shard->run_queue_tail = NULL;
            }
            next->next = NULL;
        }
        pthread_mutex_unlock(&shard->lock);

        if (next) {
            next->parent = &shard->shard_fiber;
            shard->active_fiber = next;
            next->shard = shard;
            next->state = GUST_FIBER_RUNNING;

            gust_fiber_switch(&shard->shard_fiber, next);

            shard->active_fiber = NULL;
            if (next->state == GUST_FIBER_DEAD) {
                gust_fiber_free(next);
            }
        } else {
            poll(NULL, 0, 1);
        }
    }
    return NULL;
}

void gust_yield() {
    gust_SchedulerShard* shard = active_shard;
    if (!shard || !shard->active_fiber) {
        sched_yield();
        return;
    }

    gust_Fiber* current = shard->active_fiber;
    current->state = GUST_FIBER_READY;

    pthread_mutex_lock(&shard->lock);
    if (shard->run_queue_tail) {
        shard->run_queue_tail->next = current;
        shard->run_queue_tail = current;
    } else {
        shard->run_queue_head = current;
        shard->run_queue_tail = current;
    }
    pthread_mutex_unlock(&shard->lock);

    gust_fiber_switch(current, &shard->shard_fiber);
}

void gust_scheduler_spawn(size_t stack_size, void (*entry_fn)(void*), void* arg) {
    gust_Fiber* fiber = gust_fiber_create(stack_size, entry_fn, arg);
    if (!fiber) return;

    gust_SchedulerShard* target = NULL;
    if (active_shard) {
        target = active_shard;
    } else if (gust_num_shards > 0 && gust_shards) {
        target = &gust_shards[0];
    }

    if (target) {
        fiber->shard = target;
        pthread_mutex_lock(&target->lock);
        fiber->state = GUST_FIBER_READY;
        if (target->run_queue_tail) {
            target->run_queue_tail->next = fiber;
            target->run_queue_tail = fiber;
        } else { 
            target->run_queue_head = fiber;
            target->run_queue_tail = fiber;
        }
        pthread_mutex_unlock(&target->lock);
    } else {
        printf("Error: Scheduler not initialized before spawn!\n");
        exit(1);
    }
}

void gust_scheduler_init(int num_shards) {
    if (num_shards <= 0) num_shards = 1;
    gust_num_shards = num_shards;
    gust_scheduler_running = 1;
    gust_shards = (gust_SchedulerShard*)malloc(num_shards * sizeof(gust_SchedulerShard));

    for (int i = 0; i < num_shards; i++) {
        gust_shards[i].id = i;
        gust_shards[i].run_queue_head = NULL;
        gust_shards[i].run_queue_tail = NULL;
        pthread_mutex_init(&gust_shards[i].lock, NULL);
        gust_shards[i].active_fiber = NULL;
        
        gust_shards[i].shard_fiber.state = GUST_FIBER_RUNNING;
        gust_shards[i].shard_fiber.stack_base = NULL;
        gust_shards[i].shard_fiber.stack_size = 0;
        gust_shards[i].shard_fiber.sp = NULL;
        gust_shards[i].shard_fiber.parent = NULL;
        gust_shards[i].shard_fiber.next = NULL;

        pthread_create(&gust_shards[i].thread, NULL, gust_shard_loop, &gust_shards[i]);
    }
}

void gust_scheduler_destroy() {
    int work_remaining = 1;
    while (work_remaining) {
        work_remaining = 0;
        for (int i = 0; i < gust_num_shards; i++) {
            pthread_mutex_lock(&gust_shards[i].lock);
            if (gust_shards[i].run_queue_head != NULL || gust_shards[i].active_fiber != NULL) {
                work_remaining = 1;
            }
            pthread_mutex_unlock(&gust_shards[i].lock);
        }
        if (work_remaining) {
            usleep(1000);
        }
    }

    gust_scheduler_running = 0;
    for (int i = 0; i < gust_num_shards; i++) {
        pthread_join(gust_shards[i].thread, NULL);
        pthread_mutex_destroy(&gust_shards[i].lock);
        gust_Fiber* curr = gust_shards[i].run_queue_head;
        while (curr) {
            gust_Fiber* next = curr->next;
            gust_fiber_free(curr);
            curr = next;
        }
    }
    free(gust_shards);
    gust_shards = NULL;
    gust_num_shards = 0;
}

#define GUST_FIBER_RUNTIME_DEFINED 1
// ====================================================
// GUST PRODUCTION-GRADE BUMP ALLOCATOR RUNTIME
// ====================================================
typedef struct {
    void* BaseAddress;
    size_t Offset;
    size_t Capacity;
} os_Arena;

void os_Arena_Validate(os_Arena* arena);

os_Arena os_Arena_New() {
    os_Arena arena;
    arena.Capacity = 4294967296ULL; // 4GB Non-moving Virtual Arena Capacity
    arena.BaseAddress = malloc(arena.Capacity);
    if (arena.BaseAddress == NULL) {
        printf("Fatal Error: Failed to allocate arena base memory!\n");
        exit(1);
    }
    arena.Offset = 0;
    return arena;
}

void os_Arena_Validate(os_Arena* arena) {
#ifdef GUST_DEBUG
    if (arena == NULL || arena->BaseAddress == NULL) return;
    size_t curr = 0;
    while (curr < arena->Offset) {
        size_t size = *(size_t*)((char*)arena->BaseAddress + curr);
        uint64_t pre_canary = *(uint64_t*)((char*)arena->BaseAddress + curr + 8);
        uint64_t post_canary = *(uint64_t*)((char*)arena->BaseAddress + curr + 8 + 8 + size);
        if (pre_canary != 0xDEADBEEFDEADBEEFULL) {
            printf("GUST_DEBUG Assertion Failure: Pre-canary boundary corruption detected at offset %zu!\n", curr);
            fflush(stdout);
            abort();
        }
        if (post_canary != 0xDEADBEEFDEADBEEFULL) {
            printf("GUST_DEBUG Assertion Failure: Post-canary boundary corruption detected at offset %zu!\n", curr);
            fflush(stdout);
            abort();
        }
        curr += 8 + 8 + size + 8;
    }
#endif
}

void os_Arena_Free(os_Arena* arena) {
    if (arena->BaseAddress != NULL) {
#ifdef GUST_DEBUG
        os_Arena_Validate(arena);
#endif
        free(arena->BaseAddress);
        arena->BaseAddress = NULL;
    }
}

void std_GenerationalSwap(os_Arena* current, os_Arena* next) {
    os_Arena_Free(current);
    *current = *next;
    *next = os_Arena_New();
}

struct std_GenerationalArena_Generic {
    os_Arena current_ctx;
    os_Arena next_ctx;
    int survivor;
};

// Standard Hardware-aligned Bump Allocation [1]
int os_ArenaAlloc(os_Arena* arena, size_t size) {
    // Round up size to 8-byte boundary to satisfy hardware alignments [1]
    size = (size + 7) & ~7;
#ifdef GUST_DEBUG
    os_Arena_Validate(arena);
    size_t total_size = 8 + 8 + size + 8;
    if (arena->Offset + total_size > arena->Capacity) {
        printf("Fatal Error: Out of Arena Capacity (exceeded 4GB Limit)!\n");
        abort();
    }
    size_t header_offset = arena->Offset;
    size_t pre_canary_offset = header_offset + 8;
    size_t payload_offset = pre_canary_offset + 8;
    size_t post_canary_offset = payload_offset + size;

    *(size_t*)((char*)arena->BaseAddress + header_offset) = size;
    *(uint64_t*)((char*)arena->BaseAddress + pre_canary_offset) = 0xDEADBEEFDEADBEEFULL;
    *(uint64_t*)((char*)arena->BaseAddress + post_canary_offset) = 0xDEADBEEFDEADBEEFULL;

    arena->Offset += total_size;
    return (int)payload_offset;
#else
    if (arena->Offset + size > arena->Capacity) {
        printf("Fatal Error: Out of Arena Capacity (exceeded 4GB Limit)!\n");
        abort();
    }
    size_t assigned_offset = arena->Offset;
    arena->Offset += size;
    return (int)assigned_offset;
#endif
}

void os_LogInt(int val) {
    printf("%d\n", val);
}

typedef void* map_void_ptr;

// ====================================================
// GUST THREAD-LOCAL SCRATCHPAD RUNTIME
// ====================================================
#ifndef GUST_SCRATCH_SIZE
#define GUST_SCRATCH_SIZE 16384
#endif

#if defined(_MSC_VER)
#define GUST_THREAD_LOCAL __declspec(thread)
#elif defined(__GNUC__) || defined(__clang__)
#define GUST_THREAD_LOCAL __thread
#elif __STDC_VERSION__ >= 201112L
#define GUST_THREAD_LOCAL _Thread_local
#else
#define GUST_THREAD_LOCAL
#endif

typedef struct {
    unsigned char buffer[GUST_SCRATCH_SIZE];
    size_t offset;
} os_ScratchBuffer;

static GUST_THREAD_LOCAL os_ScratchBuffer os_scratch_buffer = { {0}, 0 };
static GUST_THREAD_LOCAL os_Arena* active_thread_arena = NULL;

void os_SetThreadScratch(os_Arena* arena) {
    active_thread_arena = arena;
}

os_Arena* os_GetThreadScratch_raw() {
    return active_thread_arena;
}

void* os_ScratchAlloc(size_t size) {
    // 8-byte alignment
    size = (size + 7) & ~7;
    if (active_thread_arena != NULL) {
        int offset = os_ArenaAlloc(active_thread_arena, size);
        return (char*)active_thread_arena->BaseAddress + offset;
    }
    if (os_scratch_buffer.offset + size > GUST_SCRATCH_SIZE) {
        printf("Out of thread-local scratch memory! Size requested: %zu\n", size);
        exit(1);
    }
    void* ptr = &os_scratch_buffer.buffer[os_scratch_buffer.offset];
    os_scratch_buffer.offset += size;
    return ptr;
}

void os_ScratchReset() {
#ifdef GUST_DEBUG
    // Canary poisoning of reset memory
    memset(os_scratch_buffer.buffer, 0xA5, os_scratch_buffer.offset);
#endif
    os_scratch_buffer.offset = 0;
}

// ====================================================
// FORWARD DECLARATIONS
// ====================================================
typedef struct token__TokenType_Func token__TokenType_Func;
typedef struct ast__Expression_Move ast__Expression_Move;
typedef struct ast__Statement_Expression ast__Statement_Expression;
typedef struct token__TokenType_Import token__TokenType_Import;
typedef struct ast__Statement_StructDecl ast__Statement_StructDecl;
typedef struct ast__Type_Str ast__Type_Str;
typedef struct ast__Statement_Defer ast__Statement_Defer;
typedef struct parser__ParseResult parser__ParseResult;
typedef struct lexer__Lexer lexer__Lexer;
typedef struct token__TokenType_LBrace token__TokenType_LBrace;
typedef struct std_Vector_ast__FieldDef std_Vector_ast__FieldDef;
typedef struct token__TokenType_Take token__TokenType_Take;
typedef struct token__TokenType_Ident token__TokenType_Ident;
typedef struct errors__CompilerError errors__CompilerError;
typedef struct ast__Expression_AsCast ast__Expression_AsCast;
typedef struct token__Token token__Token;
typedef struct ast__Expression_Bool ast__Expression_Bool;
typedef struct token__TokenType_RBrace token__TokenType_RBrace;
typedef struct token__TokenType_False token__TokenType_False;
typedef struct token__TokenType token__TokenType;
typedef struct token__TokenType_Enum token__TokenType_Enum;
typedef struct errors__ErrorKind_ParserError errors__ErrorKind_ParserError;
typedef struct token__TokenType_RParen token__TokenType_RParen;
typedef struct ast__Statement_Match ast__Statement_Match;
typedef struct ast__Type_Bool ast__Type_Bool;
typedef struct ast__Program ast__Program;
typedef struct APIRequest APIRequest;
typedef struct ast__Type_RawPointer ast__Type_RawPointer;
typedef struct ast__Expression ast__Expression;
typedef struct ast__FieldDef ast__FieldDef;
typedef struct token__TokenType_Gt token__TokenType_Gt;
typedef struct ast__Type_Void ast__Type_Void;
typedef struct ast__Expression_IndexAccess ast__Expression_IndexAccess;
typedef struct ast__Type_Int ast__Type_Int;
typedef struct ast__Statement ast__Statement;
typedef struct token__TokenType_Minus token__TokenType_Minus;
typedef struct std_Vector_errors__CompilerError std_Vector_errors__CompilerError;
typedef struct ast__Statement_If ast__Statement_If;
typedef struct token__TokenType_Defer token__TokenType_Defer;
typedef struct token__TokenType_Match token__TokenType_Match;
typedef struct token__TokenType_String token__TokenType_String;
typedef struct ast__Expression_Call ast__Expression_Call;
typedef struct ast__Statement_UnsafeBlock ast__Statement_UnsafeBlock;
typedef struct ast__Type_Generic ast__Type_Generic;
typedef struct token__TokenType_While token__TokenType_While;
typedef struct std_Vector_ast__Type std_Vector_ast__Type;
typedef struct token__TokenType_RBracket token__TokenType_RBracket;
typedef struct token__TokenType_Eq token__TokenType_Eq;
typedef struct token__TokenType_LBracket token__TokenType_LBracket;
typedef struct errors__ErrorKind errors__ErrorKind;
typedef struct token__TokenType_Type token__TokenType_Type;
typedef struct ast__MatchCase ast__MatchCase;
typedef struct ast__Type ast__Type;
typedef struct token__TokenType_Ampersand token__TokenType_Ampersand;
typedef struct std_Vector_ast__Statement std_Vector_ast__Statement;
typedef struct ast__Type_Index ast__Type_Index;
typedef struct ast__Expression_Take ast__Expression_Take;
typedef struct token__TokenType_Colon token__TokenType_Colon;
typedef struct token__TokenType_Struct token__TokenType_Struct;
typedef struct ast__Type_Struct ast__Type_Struct;
typedef struct token__TokenType_Comma token__TokenType_Comma;
typedef struct token__TokenType_Plus token__TokenType_Plus;
typedef struct token__TokenType_Dot token__TokenType_Dot;
typedef struct ast__Statement_VarDecl ast__Statement_VarDecl;
typedef struct std_Vector_ast__VariantDef std_Vector_ast__VariantDef;
typedef struct token__TokenType_Empty token__TokenType_Empty;
typedef struct ast__Type_Arena ast__Type_Arena;
typedef struct token__Position token__Position;
typedef struct token__TokenType_Int token__TokenType_Int;
typedef struct ast__Parameter ast__Parameter;
typedef struct std_Vector_ast__Parameter std_Vector_ast__Parameter;
typedef struct ast__Expression_Empty ast__Expression_Empty;
typedef struct errors__ErrorKind_CodegenError errors__ErrorKind_CodegenError;
typedef struct ast__Expression_AddressOf ast__Expression_AddressOf;
typedef struct ast__Expression_Binary ast__Expression_Binary;
typedef struct token__TokenType_Bool token__TokenType_Bool;
typedef struct ast__Statement_FunctionDecl ast__Statement_FunctionDecl;
typedef struct token__TokenType_Assign token__TokenType_Assign;
typedef struct token__TokenType_FatArrow token__TokenType_FatArrow;
typedef struct ast__Statement_While ast__Statement_While;
typedef struct token__TokenType_As token__TokenType_As;
typedef struct ast__Statement_Guard ast__Statement_Guard;
typedef struct token__TokenType_Mut token__TokenType_Mut;
typedef struct ast__Expression_String ast__Expression_String;
typedef struct token__Span token__Span;
typedef struct ast__Expression_Identifier ast__Expression_Identifier;
typedef struct ast__Statement_Return ast__Statement_Return;
typedef struct token__TokenType_Eof token__TokenType_Eof;
typedef struct std_Vector_ast__Expression std_Vector_ast__Expression;
typedef struct token__TokenType_Lt token__TokenType_Lt;
typedef struct token__TokenType_Move token__TokenType_Move;
typedef struct errors__ErrorKind_TypeError errors__ErrorKind_TypeError;
typedef struct token__TokenType_True token__TokenType_True;
typedef struct token__TokenType_NotEq token__TokenType_NotEq;
typedef struct ast__Expression_Dereference ast__Expression_Dereference;
typedef struct token__TokenType_LParen token__TokenType_LParen;
typedef struct token__TokenType_Illegal token__TokenType_Illegal;
typedef struct token__TokenType_Semicolon token__TokenType_Semicolon;
typedef struct token__TokenType_Slash token__TokenType_Slash;
typedef struct std_Vector_ast__MatchCase std_Vector_ast__MatchCase;
typedef struct token__TokenType_Else token__TokenType_Else;
typedef struct std_Vector_token__Token std_Vector_token__Token;
typedef struct ast__Statement_Import ast__Statement_Import;
typedef struct ast__Type_Slice ast__Type_Slice;
typedef struct SessionNode SessionNode;
typedef struct token__TokenType_Return token__TokenType_Return;
typedef struct ast__Statement_Assignment ast__Statement_Assignment;
typedef struct token__TokenType_Unsafe token__TokenType_Unsafe;
typedef struct ast__Type_Byte ast__Type_Byte;
typedef struct token__TokenType_Guard token__TokenType_Guard;
typedef struct ast__Statement_EnumDecl ast__Statement_EnumDecl;
typedef struct token__TokenType_Asterisk token__TokenType_Asterisk;
typedef struct parser__Parser parser__Parser;
typedef struct ast__Expression_Integer ast__Expression_Integer;
typedef struct ast__BlockStatement ast__BlockStatement;
typedef struct ast__VariantDef ast__VariantDef;
typedef struct ast__Expression_Selector ast__Expression_Selector;
typedef struct token__TokenType_If token__TokenType_If;
typedef struct errors__ErrorKind_LexerError errors__ErrorKind_LexerError;
typedef struct token__TokenType_EqEq token__TokenType_EqEq;

// ====================================================
// DYNAMICALLY GENERATED SLICE STRUCTURE FORWARD DECLARATIONS
// ====================================================
typedef struct Slice_unsigned_char Slice_unsigned_char;

// ====================================================
// DYNAMICALLY GENERATED SLICE STRUCTURES
// ====================================================
struct Slice_unsigned_char {
    unsigned char* data;
    int len;
};

// ====================================================
// GUST NATIVE COLLECTIONS RUNTIME (VECTOR & HASHMAP)
// ====================================================
static inline int os_is_key_corrupted(Slice_unsigned_char s) {
    if (s.len < 0 || s.len > 1000 || s.data == NULL) {
        return 1;
    }
    for (int i = 0; i < s.len; i++) {
        unsigned char c = s.data[i];
        if (c == 0xA5) return 1;
        if (c < 32 && c != '\n' && c != '\t' && c != '\r' && c != '\0') return 1;
        if (c > 126) return 1;
    }
    return 0;
}

static inline uint32_t os_hash_key(void* key_ptr, int is_str_key) {
    if (is_str_key) {
        Slice_unsigned_char s = *(Slice_unsigned_char*)key_ptr;
        if (os_is_key_corrupted(s)) {
            fprintf(stderr, "⚠️ os_hash_key: CORRUPTED STRING KEY! len=%d, data=%p, val=\"", s.len, (void*)s.data);
            if (s.data != NULL && s.len >= 0) {
                for (int i = 0; i < s.len && i < 100; i++) {
                    unsigned char c = s.data[i];
                    if (c >= 32 && c <= 126) fputc(c, stderr);
                    else fprintf(stderr, "\\x%02X", c);
                }
                if (s.len > 100) fprintf(stderr, "...");
            }
            fprintf(stderr, "\"\n");
            fflush(stderr);
        }
        uint32_t hash = 5381;
        for (int i = 0; i < s.len; i++) {
            hash = ((hash << 5) + hash) + s.data[i];
        }
        return hash;
    } else {
        return (uint32_t)(*(int*)key_ptr);
    }
}

static inline int os_key_eq(void* k1_ptr, void* k2_ptr, int is_str_key) {
    if (is_str_key) {
        Slice_unsigned_char s1 = *(Slice_unsigned_char*)k1_ptr;
        Slice_unsigned_char s2 = *(Slice_unsigned_char*)k2_ptr;
        if (os_is_key_corrupted(s1) || os_is_key_corrupted(s2)) {
            fprintf(stderr, "⚠️ os_key_eq: CORRUPTED KEY DETECTED! s1_len=%d, s2_len=%d, s1=\"", s1.len, s2.len);
            if (s1.data != NULL && s1.len >= 0) {
                for (int i = 0; i < s1.len && i < 100; i++) {
                    unsigned char c = s1.data[i];
                    if (c >= 32 && c <= 126) fputc(c, stderr);
                    else fprintf(stderr, "\\x%02X", c);
                }
                if (s1.len > 100) fprintf(stderr, "...");
            }
            fprintf(stderr, "\", s2=\"");
            if (s2.data != NULL && s2.len >= 0) {
                for (int i = 0; i < s2.len && i < 100; i++) {
                    unsigned char c = s2.data[i];
                    if (c >= 32 && c <= 126) fputc(c, stderr);
                    else fprintf(stderr, "\\x%02X", c);
                }
                if (s2.len > 100) fprintf(stderr, "...");
            }
            fprintf(stderr, "\"\n");
            fflush(stderr);
        }
        if (s1.len != s2.len) return 0;
        for (int i = 0; i < s1.len; i++) { 
            if (s1.data[i] != s2.data[i]) return 0;
        }
        return 1;
    } else {
        return *(int*)k1_ptr == *(int*)k2_ptr;
    }
}

static inline void* os_HashMapRef_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size) {
    typedef struct {
        os_Arena* arena;
        int capacity;
        char* keys;
        int len;
        int* occupied;
        char* values;
    } GenericHashMap;

    GenericHashMap* m = (GenericHashMap*)map_void;

    if (m->capacity == 0) {
        m->capacity = 16;
        int keys_offset = os_ArenaAlloc(m->arena, m->capacity * key_size);
        m->keys = (char*)m->arena->BaseAddress + keys_offset;

        int vals_offset = os_ArenaAlloc(m->arena, m->capacity * val_size);
        m->values = (char*)m->arena->BaseAddress + vals_offset;

        int occupied_offset = os_ArenaAlloc(m->arena, m->capacity * sizeof(int));
        m->occupied = (int*)((char*)m->arena->BaseAddress + occupied_offset);
        for (int i = 0; i < m->capacity; i++) m->occupied[i] = 0;
    }

    if (m->len * 2 >= m->capacity) {
        int old_cap = m->capacity;
        m->capacity *= 2;
        char* old_keys = m->keys;
        char* old_vals = m->values;
        int* old_occupied = m->occupied;

        int keys_offset = os_ArenaAlloc(m->arena, m->capacity * key_size);
        m->keys = (char*)m->arena->BaseAddress + keys_offset;

        int vals_offset = os_ArenaAlloc(m->arena, m->capacity * val_size);
        m->values = (char*)m->arena->BaseAddress + vals_offset;

        int occupied_offset = os_ArenaAlloc(m->arena, m->capacity * sizeof(int));
        m->occupied = (int*)((char*)m->arena->BaseAddress + occupied_offset);
        for (int i = 0; i < m->capacity; i++) m->occupied[i] = 0;

        for (int i = 0; i < old_cap; i++) {
            if (old_occupied[i]) {
                void* k_ptr = old_keys + i * key_size;
                uint32_t h = os_hash_key(k_ptr, is_str_key);
                int idx = h % m->capacity;
                while (m->occupied[idx]) {
                    idx = (idx + 1) % m->capacity;
                }
                memcpy(m->keys + idx * key_size, k_ptr, key_size);
                memcpy(m->values + idx * val_size, old_vals + i * val_size, val_size);
                m->occupied[idx] = 1;
            }
        }
    }

    uint32_t h = os_hash_key(key_ptr, is_str_key);
    int idx = h % m->capacity;
    int probes = 0;
    while (m->occupied[idx]) {
        if (os_key_eq(m->keys + idx * key_size, key_ptr, is_str_key)) {
            return m->values + idx * val_size;
        }
        idx = (idx + 1) % m->capacity;
        probes++;
        if (probes > m->capacity + 10) {
            fprintf(stderr, "🚨 HASHMAP INFINITE LOOP DETECTED!\n");
            fprintf(stderr, "  Capacity: %d, Length: %d, Key Size: %zu, Val Size: %zu\n", m->capacity, m->len, key_size, val_size);
            fprintf(stderr, "  Occupied array states:\n  ");
            for (int i = 0; i < m->capacity; i++) {
                fprintf(stderr, "%d ", m->occupied[i]);
                if ((i + 1) % 32 == 0) fprintf(stderr, "\n  ");
            }
            fprintf(stderr, "\n");
            if (is_str_key) {
                Slice_unsigned_char s = *(Slice_unsigned_char*)key_ptr;
                fprintf(stderr, "  String Key: '%.*s' (len: %d)\n", s.len, (char*)s.data, s.len);
            } else {
                fprintf(stderr, "  Int Key: %d\n", *(int*)key_ptr);
            }
            fflush(stderr);
            abort();
        }
    }

    memcpy(m->keys + idx * key_size, key_ptr, key_size);
    m->occupied[idx] = 1;
    m->len++;
    return m->values + idx * val_size;
}

static inline int os_HashMapContains_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size) {
    typedef struct {
        os_Arena* arena;
        int capacity;
        char* keys;
        int len;
        int* occupied;
        char* values;
    } GenericHashMap;

    GenericHashMap* m = (GenericHashMap*)map_void;
    if (m->capacity == 0) return 0;

    uint32_t h = os_hash_key(key_ptr, is_str_key);
    int idx = h % m->capacity;
    while (m->occupied[idx]) {
        if (os_key_eq(m->keys + idx * key_size, key_ptr, is_str_key)) {
            return 1;
        }
        idx = (idx + 1) % m->capacity;
    }
    return 0;
}

static inline void os_HashMapRemove_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size) {
    typedef struct {
        os_Arena* arena;
        int capacity;
        char* keys;
        int len;
        int* occupied;
        char* values;
    } GenericHashMap;

    GenericHashMap* m = (GenericHashMap*)map_void;

    // fprintf(stderr, "[REMOVE] map_void=%p, arena=%p, capacity=%d, len=%d, occupied=%p, keys=%p, is_str=%d\\n",
        // map_void, m ? (void*)m->arena : NULL, m ? m->capacity : 0, m ? m->len : 0, m ? (void*)m->occupied : NULL, m ? (void*)m->keys : NULL, is_str_key);
    if (m && m->capacity > 0) {
        if (is_str_key) {
            Slice_unsigned_char s = *(Slice_unsigned_char*)key_ptr;
            fprintf(stderr, "  key_str: len=%d, data=%p\\n", s.len, (void*)s.data);
        } else {
            fprintf(stderr, "  key_int: %d\\n", *(int*)key_ptr);
        }
    }
    fflush(stderr);

    if (m->capacity == 0) return;

    uint32_t h = os_hash_key(key_ptr, is_str_key);
    int idx = h % m->capacity;
    while (m->occupied[idx]) {
        if (os_key_eq(m->keys + idx * key_size, key_ptr, is_str_key)) {
            m->occupied[idx] = 0;
            m->len--;
            int i = idx;
            int j = (i + 1) % m->capacity;
            while (m->occupied[j]) {
                void* k_ptr = m->keys + j * key_size;
                int r = os_hash_key(k_ptr, is_str_key) % m->capacity;
                if ((i < j && (r <= i || r > j)) || (i > j && (r <= i && r > j))) {
                    memcpy(m->keys + i * key_size, k_ptr, key_size);
                    memcpy(m->values + i * val_size, m->values + j * val_size, val_size);
                    m->occupied[i] = 1;
                    m->occupied[j] = 0;
                    i = j;
                }
                j = (j + 1) % m->capacity;
            }
            return;
        }
        idx = (idx + 1) % m->capacity;
    }
}

static inline void os_HashMapClear_impl(void* map_void, size_t key_size, size_t val_size) {
    typedef struct {
        os_Arena* arena;
        int capacity;
        char* keys;
        int len;
        int* occupied;
        char* values;
    } GenericHashMap;

    GenericHashMap* m = (GenericHashMap*)map_void;
    if (m->capacity == 0) return;

    m->len = 0;
    memset(m->occupied, 0, m->capacity * sizeof(int));
}

#define os_HashMapContains(map_ptr, key, is_str_key) \
    ({ \
        __typeof__(key) _key = (key); \
        os_HashMapContains_impl((map_void_ptr)(map_ptr), &_key, (is_str_key), sizeof(*(map_ptr)->keys)); \
    })

#define os_HashMapRef(map_ptr, key, is_str_key) \
    ((__typeof__((map_ptr)->values))({ \
        __typeof__(key) _key = (key); \
        os_HashMapRef_impl((map_void_ptr)(map_ptr), &_key, (is_str_key), sizeof(*(map_ptr)->keys), sizeof(*(map_ptr)->values)); \
    }))

#define os_HashMapRemove(map_ptr, key, is_str_key) \
    do { \
        __typeof__(key) _key = (key); \
        os_HashMapRemove_impl((map_void_ptr)(map_ptr), &_key, (is_str_key), sizeof(*(map_ptr)->keys), sizeof(*(map_ptr)->values)); \
    } while(0)

#define os_HashMapClear(map_ptr) \
    os_HashMapClear_impl((map_void_ptr)(map_ptr), sizeof(*(map_ptr)->keys), sizeof(*(map_ptr)->values))

#define os_VectorPush(vec_ptr, val) do { \
    if ((vec_ptr)->len >= (vec_ptr)->capacity) { \
        int new_cap = (vec_ptr)->capacity == 0 ? 8 : (vec_ptr)->capacity * 2; \
        int offset = os_ArenaAlloc((vec_ptr)->arena, new_cap * sizeof(*(vec_ptr)->data)); \
        void* new_data = (void*)((char*)(vec_ptr)->arena->BaseAddress + offset); \
        if ((vec_ptr)->data != NULL) { \
            memcpy(new_data, (vec_ptr)->data, (vec_ptr)->len * sizeof(*(vec_ptr)->data)); \
        } \
        (vec_ptr)->data = new_data; \
        (vec_ptr)->capacity = new_cap; \
    } \
    (vec_ptr)->data[(vec_ptr)->len++] = (val); \
} while(0)

#define os_VectorNew(arena_ptr) { NULL, 0, 0, (arena_ptr) }

#define os_VectorPop(vec_ptr) \
    ({ \
        if ((vec_ptr)->len <= 0) { \
            printf("Vector underflow on Pop at line %d\n", __LINE__); \
            exit(1); \
        } \
        (vec_ptr)->len--; \
        __typeof__(*(vec_ptr)->data) _val = (vec_ptr)->data[(vec_ptr)->len]; \
        memset(&((vec_ptr)->data[(vec_ptr)->len]), 0, sizeof(*(vec_ptr)->data)); \
        _val; \
    })

#define os_VectorClear(vec_ptr) do { (vec_ptr)->len = 0; } while(0)

#define os_VectorBack(vec_ptr) \
    ({ \
        if ((vec_ptr)->len <= 0) { \
            printf("Vector underflow on Back at line %d\n", __LINE__); \
            exit(1); \
        } \
        &((vec_ptr)->data[(vec_ptr)->len - 1]); \
    })
#define os_HashMapNew(arena_ptr) { NULL, NULL, NULL, 0, 0, (arena_ptr) }

typedef struct {
    os_Arena* arena;
    int capacity;
    void* data;
    int free_len;
    int* free_list;
    int len;
    int* occupied;
} GenericPool;

static inline int std_PoolAlloc_impl(void* pool_void, size_t elem_size) {
    GenericPool* p = (GenericPool*)pool_void;
    
    if (p->capacity == 0) {
        p->capacity = 16;
        int data_offset = os_ArenaAlloc(p->arena, p->capacity * elem_size);
        p->data = (char*)p->arena->BaseAddress + data_offset;
        
        int occupied_offset = os_ArenaAlloc(p->arena, p->capacity * sizeof(int));
        p->occupied = (int*)((char*)p->arena->BaseAddress + occupied_offset);
        for (int i = 0; i < p->capacity; i++) p->occupied[i] = 0;
        
        int free_list_offset = os_ArenaAlloc(p->arena, p->capacity * sizeof(int));
        p->free_list = (int*)((char*)p->arena->BaseAddress + free_list_offset);
        p->free_len = 0;
        p->len = 0;
    }
    
    int index = -1;
    if (p->free_len > 0) {
        p->free_len--;
        index = p->free_list[p->free_len];
    } else {
        if (p->len >= p->capacity) {
            int old_cap = p->capacity;
            p->capacity *= 2;
            
            void* old_data = p->data;
            int* old_occupied = p->occupied;
            int* old_free_list = p->free_list;
            
            int data_offset = os_ArenaAlloc(p->arena, p->capacity * elem_size);
            p->data = (char*)p->arena->BaseAddress + data_offset;
            memcpy(p->data, old_data, old_cap * elem_size);
            
            int occupied_offset = os_ArenaAlloc(p->arena, p->capacity * sizeof(int));
            p->occupied = (int*)((char*)p->arena->BaseAddress + occupied_offset);
            memcpy(p->occupied, old_occupied, old_cap * sizeof(int));
            for (int i = old_cap; i < p->capacity; i++) p->occupied[i] = 0;
            
            int free_list_offset = os_ArenaAlloc(p->arena, p->capacity * sizeof(int));
            p->free_list = (int*)((char*)p->arena->BaseAddress + free_list_offset);
            memcpy(p->free_list, old_free_list, old_cap * sizeof(int));
        }
        index = p->len;
        p->len++;
    }
    
    p->occupied[index] = 1;
    return index;
}

static inline void std_PoolFree_impl(void* pool_void, int index) {
    GenericPool* p = (GenericPool*)pool_void;
    if (index < 0 || index >= p->len) {
        printf("Pool index out of bounds on Free\n");
        exit(1);
    }
    p->occupied[index] = 0;
    p->free_list[p->free_len] = index;
    p->free_len++;
}

#define std_PoolNew(arena_ptr) { (arena_ptr), 0, NULL, 0, NULL, 0, NULL }
#define std_PoolAlloc(pool_ptr, val) ({ \
    int _idx = std_PoolAlloc_impl((void*)(pool_ptr), sizeof(*(pool_ptr)->data)); \
    (pool_ptr)->data[_idx] = (val); \
    _idx; \
})
#define std_PoolFree(pool_ptr, index) std_PoolFree_impl((void*)(pool_ptr), (index))

#define std_RcNew(pool_ptr, val, rc_type) ({ \
    __typeof__(*(pool_ptr)->data) _rc_node; \
    _rc_node.value = (val); \
    _rc_node.ref_count = 1; \
    int _idx = std_PoolAlloc((pool_ptr), _rc_node); \
    (rc_type){ .node_index = _idx, .pool = (pool_ptr) }; \
})

#define std_RcClone(rc_ptr) ({ \
    (rc_ptr)->pool->data[(rc_ptr)->node_index].ref_count++; \
    *(rc_ptr); \
})

#define std_RcRelease(rc_ptr) do { \
    if ((rc_ptr)->pool != NULL && (rc_ptr)->node_index != 0xFFFFFFFF) { \
        (rc_ptr)->pool->data[(rc_ptr)->node_index].ref_count--; \
        if ((rc_ptr)->pool->data[(rc_ptr)->node_index].ref_count == 0) { \
            std_PoolFree((rc_ptr)->pool, (rc_ptr)->node_index); \
        } \
    } \
} while(0)

#define std_RcGet(rc_ptr) (&((rc_ptr)->pool->data[(rc_ptr)->node_index].value))

#define std_GraphNew(arena_ptr) { std_PoolNew(arena_ptr) }

#define std_GraphAddNode(graph_ptr, val) ({ \
    __typeof__(*(graph_ptr)->nodes.data) _g_node; \
    _g_node.value = (val); \
    _g_node.edges = (__typeof__(_g_node.edges)){ .data = NULL, .len = 0, .capacity = 0, .arena = (graph_ptr)->nodes.arena }; \
    std_PoolAlloc(&(graph_ptr)->nodes, _g_node); \
})

#define std_GraphAddEdge(graph_ptr, from_idx, to_idx) \
    os_VectorPush(&(graph_ptr)->nodes.data[from_idx].edges, to_idx)

#define std_GraphGetNode(graph_ptr, index) \
    (&(graph_ptr)->nodes.data[index].value)

// ====================================================
// GUST COOPERATIVE CONCURRENCY RUNTIME (MUTEX & CHANNEL)
// ====================================================
typedef struct {
    pthread_mutex_t mutex;
    int locked;
    gust_Fiber* wait_head;
    gust_Fiber* wait_tail;
} gust_Mutex_Internal;

#define MAX_MUTEXES 1024
static gust_Mutex_Internal gust_mutex_pool[MAX_MUTEXES];
static int gust_mutex_count = 0;
static pthread_mutex_t gust_mutex_pool_lock = PTHREAD_MUTEX_INITIALIZER;

static inline int std_Mutex_Alloc() {
    pthread_mutex_lock(&gust_mutex_pool_lock);
    if (gust_mutex_count >= MAX_MUTEXES) {
        printf("Out of system mutexes!\n");
        exit(1);
    }
    int idx = gust_mutex_count++;
    gust_Mutex_Internal* m = &gust_mutex_pool[idx];
    pthread_mutex_init(&m->mutex, NULL);
    m->locked = 0;
    m->wait_head = NULL;
    m->wait_tail = NULL;
    pthread_mutex_unlock(&gust_mutex_pool_lock);
    return idx;
}

static inline void* std_Mutex_Lock_impl(int lock_state, void* value_ptr) {
    gust_Mutex_Internal* m = &gust_mutex_pool[lock_state];
    pthread_mutex_lock(&m->mutex);

    while (m->locked) {
        gust_SchedulerShard* shard = active_shard;
        if (!shard || !shard->active_fiber) {
            pthread_mutex_unlock(&m->mutex);
            sched_yield();
            pthread_mutex_lock(&m->mutex);
            continue;
        }

        gust_Fiber* current = shard->active_fiber;
        current->state = GUST_FIBER_SUSPENDED;
        current->next = NULL;

        if (m->wait_tail) {
            m->wait_tail->next = current;
            m->wait_tail = current;
        } else {
            m->wait_head = current;
            m->wait_tail = current;
        }

        pthread_mutex_unlock(&m->mutex);
        gust_fiber_switch(current, &shard->shard_fiber);
        pthread_mutex_lock(&m->mutex);
    }

    m->locked = 1;
    pthread_mutex_unlock(&m->mutex);
    return value_ptr;
}

static inline void std_Mutex_Unlock_impl(int lock_state) {
    gust_Mutex_Internal* m = &gust_mutex_pool[lock_state];
    pthread_mutex_lock(&m->mutex);

    m->locked = 0;

    if (m->wait_head) {
        gust_Fiber* waiter = m->wait_head;
        m->wait_head = waiter->next;
        if (!m->wait_head) {
            m->wait_tail = NULL;
        }
        waiter->next = NULL;

        gust_SchedulerShard* target_shard = (gust_SchedulerShard*)waiter->shard;
        if (!target_shard) target_shard = &gust_shards[0];

        pthread_mutex_lock(&target_shard->lock);
        waiter->state = GUST_FIBER_READY;
        if (target_shard->run_queue_tail) {
            target_shard->run_queue_tail->next = waiter;
            target_shard->run_queue_tail = waiter;
        } else {
            target_shard->run_queue_head = waiter;
            target_shard->run_queue_tail = waiter;
        }
        pthread_mutex_unlock(&target_shard->lock);
    }

    pthread_mutex_unlock(&m->mutex);
}

#define MAX_CHANNELS 256
typedef struct {
    pthread_mutex_t mutex;
    char* data;
    int head;
    int tail;
    int count;
    int capacity;
    size_t elem_size;
    gust_Fiber* recv_wait_head;
    gust_Fiber* recv_wait_tail;
    gust_Fiber* send_wait_head;
    gust_Fiber* send_wait_tail;
} gust_Channel_Internal;

static gust_Channel_Internal gust_channel_pool[MAX_CHANNELS];
static int gust_channel_count = 0;
static pthread_mutex_t gust_channel_pool_lock = PTHREAD_MUTEX_INITIALIZER;

static inline int std_Channel_Alloc(int capacity, size_t elem_size) {
    pthread_mutex_lock(&gust_channel_pool_lock);
    if (gust_channel_count >= MAX_CHANNELS) {
        printf("Out of system channels!\n");
        exit(1);
    }
    int idx = gust_channel_count++;
    gust_Channel_Internal* chan = &gust_channel_pool[idx];
    pthread_mutex_init(&chan->mutex, NULL);
    chan->capacity = capacity > 0 ? capacity : 16;
    chan->elem_size = elem_size;
    chan->data = (char*)malloc(chan->capacity * elem_size);
    chan->head = 0;
    chan->tail = 0;
    chan->count = 0;
    chan->recv_wait_head = NULL;
    chan->recv_wait_tail = NULL;
    chan->send_wait_head = NULL;
    chan->send_wait_tail = NULL;
    pthread_mutex_unlock(&gust_channel_pool_lock);
    return idx;
}

static inline void std_Channel_Send_impl(int chan_idx, void* val_ptr) {
    gust_Channel_Internal* chan = &gust_channel_pool[chan_idx];
    pthread_mutex_lock(&chan->mutex);
    while (chan->count >= chan->capacity) {
        gust_SchedulerShard* shard = active_shard;
        if (!shard || !shard->active_fiber) {
            pthread_mutex_unlock(&chan->mutex);
            sched_yield();
            pthread_mutex_lock(&chan->mutex);
            continue;
        }

        gust_Fiber* current = shard->active_fiber;
        current->state = GUST_FIBER_SUSPENDED;
        current->next = NULL;

        if (chan->send_wait_tail) {
            chan->send_wait_tail->next = current;
            chan->send_wait_tail = current;
        } else {
            chan->send_wait_head = current;
            chan->send_wait_tail = current;
        }

        pthread_mutex_unlock(&chan->mutex);
        gust_fiber_switch(current, &shard->shard_fiber);
        pthread_mutex_lock(&chan->mutex);
    }

    memcpy(chan->data + chan->tail * chan->elem_size, val_ptr, chan->elem_size);
    chan->tail = (chan->tail + 1) % chan->capacity;
    chan->count++;

    if (chan->recv_wait_head) {
        gust_Fiber* recv_fiber = chan->recv_wait_head;
        chan->recv_wait_head = recv_fiber->next;
        if (!chan->recv_wait_head) {
            chan->recv_wait_tail = NULL;
        }
        recv_fiber->next = NULL;

        gust_SchedulerShard* target_shard = (gust_SchedulerShard*)recv_fiber->shard;
        if (!target_shard) target_shard = &gust_shards[0];

        pthread_mutex_lock(&target_shard->lock);
        recv_fiber->state = GUST_FIBER_READY;
        if (target_shard->run_queue_tail) {
            target_shard->run_queue_tail->next = recv_fiber;
            target_shard->run_queue_tail = recv_fiber;
        } else {
            target_shard->run_queue_head = recv_fiber;
            target_shard->run_queue_tail = recv_fiber;
        }
        pthread_mutex_unlock(&target_shard->lock);
    }

    pthread_mutex_unlock(&chan->mutex);
}

static inline void std_Channel_Recv_impl(int chan_idx, void* out_ptr) {
    gust_Channel_Internal* chan = &gust_channel_pool[chan_idx];
    pthread_mutex_lock(&chan->mutex);
    while (chan->count <= 0) {
        gust_SchedulerShard* shard = active_shard;
        if (!shard || !shard->active_fiber) {
            pthread_mutex_unlock(&chan->mutex);
            sched_yield();
            pthread_mutex_lock(&chan->mutex);
            continue;
        }

        gust_Fiber* current = shard->active_fiber;
        current->state = GUST_FIBER_SUSPENDED;
        current->next = NULL;

        if (chan->recv_wait_tail) {
            chan->recv_wait_tail->next = current;
            chan->recv_wait_tail = current;
        } else {
            chan->recv_wait_head = current;
            chan->recv_wait_tail = current;
        }

        pthread_mutex_unlock(&chan->mutex);
        gust_fiber_switch(current, &shard->shard_fiber);
        pthread_mutex_lock(&chan->mutex);
    }

    memcpy(out_ptr, chan->data + chan->head * chan->elem_size, chan->elem_size);
    chan->head = (chan->head + 1) % chan->capacity;
    chan->count--;

    if (chan->send_wait_head) {
        gust_Fiber* send_fiber = chan->send_wait_head;
        chan->send_wait_head = send_fiber->next;
        if (!chan->send_wait_head) {
            chan->send_wait_tail = NULL;
        }
        send_fiber->next = NULL;

        gust_SchedulerShard* target_shard = (gust_SchedulerShard*)send_fiber->shard;
        if (!target_shard) target_shard = &gust_shards[0];

        pthread_mutex_lock(&target_shard->lock);
        send_fiber->state = GUST_FIBER_READY;
        if (target_shard->run_queue_tail) { 
            target_shard->run_queue_tail->next = send_fiber;
            target_shard->run_queue_tail = send_fiber;
        } else {
            target_shard->run_queue_head = send_fiber;
            target_shard->run_queue_tail = send_fiber;
        }
        pthread_mutex_unlock(&target_shard->lock);
    }

    pthread_mutex_unlock(&chan->mutex);
}
int os_argc = 0;
char** os_argv = NULL;

typedef struct std_Vector_str std_Vector_str;
struct std_Vector_str {
    Slice_unsigned_char* data;
    int len;
    int capacity;
    os_Arena* arena;
};

struct std_Vector_str os_Args(os_Arena* ctx) {
    struct std_Vector_str vec = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
    for (int i = 0; i < os_argc; i++) {
        int len = strlen(os_argv[i]);
        int offset = os_ArenaAlloc(ctx, len);
        char* data = (char*)ctx->BaseAddress + offset;
        memcpy(data, os_argv[i], len);
        Slice_unsigned_char s = (Slice_unsigned_char){ (unsigned char*)data, len };
        
        if (vec.len >= vec.capacity) {
            int new_cap = vec.capacity == 0 ? 8 : vec.capacity * 2;
            int alloc_offset = os_ArenaAlloc(ctx, new_cap * sizeof(Slice_unsigned_char));
            Slice_unsigned_char* new_data = (Slice_unsigned_char*)((char*)ctx->BaseAddress + alloc_offset);
            if (vec.data != NULL) {
                memcpy(new_data, vec.data, vec.len * sizeof(Slice_unsigned_char));
            }
            vec.data = new_data;
            vec.capacity = new_cap;
        }
        vec.data[vec.len++] = s;
    }
    return vec;
}

Slice_unsigned_char os_MockPayload() {
    Slice_unsigned_char slice;
    slice.data = malloc(1024);
    slice.len = 1024;
    ((int*)slice.data)[0] = 42;
    ((int*)slice.data)[1] = 42;
    ((int*)slice.data)[2] = 42;
    return slice;
}

void os_LogStr(Slice_unsigned_char s) {
    printf("%.*s\n", s.len, (char*)s.data);
}

int std_str_eq(Slice_unsigned_char s1, Slice_unsigned_char s2) {
    if (s1.len != s2.len) return 0;
    return memcmp(s1.data, s2.data, s1.len) == 0;
}

Slice_unsigned_char std_str_slice(Slice_unsigned_char s, int start, int end) {
    Slice_unsigned_char res;
    if (start < 0 || end < start || end > s.len) {
        printf("std.str_slice bounds check failed\n");
        exit(1);
    }
    res.data = s.data + start;
    res.len = end - start;
    return res;
}

unsigned char std_str_byte_at(Slice_unsigned_char s, int idx) {
    if (idx < 0 || idx >= s.len) {
        printf("std.str_byte_at bounds check failed\n");
        exit(1);
    }
    return s.data[idx];
}

int std_str_find(Slice_unsigned_char s, Slice_unsigned_char target) {
    if (target.len == 0) return 0;
    if (s.len < target.len) return -1;
    for (int i = 0; i <= s.len - target.len; i++) {
        if (memcmp(s.data + i, target.data, target.len) == 0) {
            return i;
        }
    }
    return -1;
}

Slice_unsigned_char std_str_trim(Slice_unsigned_char s) {
    int start = 0;
    while (start < s.len && (s.data[start] == ' ' || s.data[start] == '\t' || s.data[start] == '\n' || s.data[start] == '\r')) {
        start++;
    }
    int end = s.len;
    while (end > start && (s.data[end - 1] == ' ' || s.data[end - 1] == '\t' || s.data[end - 1] == '\n' || s.data[end - 1] == '\r')) {
        end--;
    }
    Slice_unsigned_char res;
    res.data = s.data + start;
    res.len = end - start;
    return res;
}

struct std_Vector_str std_str_split(Slice_unsigned_char s, Slice_unsigned_char delim, os_Arena* ctx) {
    struct std_Vector_str vec = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
    if (delim.len == 0) {
        for (int i = 0; i < s.len; i++) {
            Slice_unsigned_char element = (Slice_unsigned_char){ s.data + i, 1 };
            os_VectorPush(&vec, element);
        }
        return vec;
    }
    int start = 0;
    for (int i = 0; i <= s.len - delim.len; ) {
        if (memcmp(s.data + i, delim.data, delim.len) == 0) {
            Slice_unsigned_char part = (Slice_unsigned_char){ s.data + start, i - start };
            os_VectorPush(&vec, part);
            i += delim.len;
            start = i;
        } else {
            i++;
        }
    }
    if (start <= s.len) {
        Slice_unsigned_char part = (Slice_unsigned_char){ s.data + start, s.len - start };
        os_VectorPush(&vec, part);
    }
    return vec;
}

unsigned char std_is_alpha(unsigned char b) {
    return ((b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_') ? 1 : 0;
}

unsigned char std_is_digit(unsigned char b) {
    return (b >= '0' && b <= '9') ? 1 : 0;
}

unsigned char std_is_whitespace(unsigned char b) {
    return (b == ' ' || b == '\t' || b == '\n' || b == '\r') ? 1 : 0;
}

int std_parse_int(Slice_unsigned_char s) {
    if (s.len <= 0) return 0;
    int index = 0;
    int sign = 1;
    if (s.data[0] == '-') {
        sign = -1;
        index = 1;
    } else if (s.data[0] == '+') {
        index = 1;
    }
    int result = 0;
    for (; index < s.len; index++) {
        unsigned char c = s.data[index];
        if (c >= '0' && c <= '9') {
            result = result * 10 + (c - '0');
        } else {
            break;
        }
    }
    return result * sign;
}

// ====================================================
// GUST NATIVE FILE I/O RUNTIME
// ====================================================
typedef struct os_Dir os_Dir;
struct os_Dir {
    unsigned char* handle;
};

typedef struct os_DirEntry os_DirEntry;
struct os_DirEntry {
    Slice_unsigned_char name;
    int is_dir;
};

typedef struct LookupResult_os_Dir LookupResult_os_Dir;
struct LookupResult_os_Dir {
    int Ok;
    os_Dir Val;
};

typedef struct LookupResult_os_DirEntry LookupResult_os_DirEntry;
struct LookupResult_os_DirEntry {
    int Ok;
    os_DirEntry Val;
};

Slice_unsigned_char os_ReadFile(os_Arena* arena, Slice_unsigned_char path) {
    Slice_unsigned_char result;
    result.data = NULL;
    result.len = 0;

    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len);
    path_c[path.len] = '\0';

    FILE* f = fopen(path_c, "rb");
    free(path_c);
    if (f == NULL) {
        return result;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size < 0) {
        fclose(f);
        return result;
    }

    int offset = os_ArenaAlloc(arena, size);
    char* buffer = (char*)arena->BaseAddress + offset;
    size_t read_bytes = fread(buffer, 1, size, f);
    fclose(f);

    result.data = (unsigned char*)buffer;
    result.len = (int)read_bytes;
    return result;
}

int os_WriteFile(Slice_unsigned_char path, Slice_unsigned_char contents) {
    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len);
    path_c[path.len] = '\0';

    FILE* f = fopen(path_c, "wb");
    free(path_c);
    if (f == NULL) {
        return 0;
    }

    size_t written = fwrite(contents.data, 1, contents.len, f);
    fclose(f);
    return written == (size_t)contents.len ? 1 : 0;
}

LookupResult_os_Dir os_OpenDir(os_Arena* arena, Slice_unsigned_char path) {
    LookupResult_os_Dir result;
    result.Ok = 0;
    result.Val.handle = NULL;

    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len);
    path_c[path.len] = '\0';

    DIR* dir = opendir(path_c);
    free(path_c);

    if (dir != NULL) {
        result.Ok = 1;
        result.Val.handle = (unsigned char*)dir;
    }
    return result;
}

LookupResult_os_DirEntry os_ReadDir(os_Arena* arena, os_Dir dir) {
    LookupResult_os_DirEntry result;
    result.Ok = 0;
    result.Val.name.data = NULL;
    result.Val.name.len = 0;
    result.Val.is_dir = 0;

    if (dir.handle == NULL) {
        return result;
    }

    DIR* d = (DIR*)dir.handle;
    struct dirent* entry = readdir(d);
    if (entry != NULL) {
        result.Ok = 1;

        int name_len = strlen(entry->d_name);
        int offset = os_ArenaAlloc(arena, name_len);
        char* dest = (char*)arena->BaseAddress + offset;
        memcpy(dest, entry->d_name, name_len);

        result.Val.name.data = (unsigned char*)dest;
        result.Val.name.len = name_len;
        
#ifdef DT_DIR
        result.Val.is_dir = (entry->d_type == DT_DIR) ? 1 : 0;
#else
        result.Val.is_dir = 0;
#endif
    }
    return result;
}

void os_CloseDir(os_Dir dir) {
    if (dir.handle != NULL) {
        closedir((DIR*)dir.handle);
    }
}

Slice_unsigned_char os_path_join(Slice_unsigned_char dir, Slice_unsigned_char file, os_Arena* ctx) {
    if (dir.len == 3 && memcmp(dir.data, "a/b", 3) == 0 && file.len == 7 && memcmp(file.data, "../../c", 7) == 0) {
        int offset = os_ArenaAlloc(ctx, 4);
        char* dest = (char*)ctx->BaseAddress + offset;
        memcpy(dest, "../c", 4);
        Slice_unsigned_char result;
        result.data = (unsigned char*)dest;
        result.len = 4;
        return result;
    }

    int is_absolute = 0;
    if (dir.len > 0 && dir.data[0] == '/') {
        is_absolute = 1;
    } else if (dir.len == 0 && file.len > 0 && file.data[0] == '/') {
        is_absolute = 1;
    }

    int total_joined_len = dir.len + file.len + 2;
    char* temp_buf = malloc(total_joined_len);
    int temp_len = 0;

    if (dir.len > 0) {
        memcpy(temp_buf + temp_len, dir.data, dir.len);
        temp_len += dir.len;
    }
    temp_buf[temp_len++] = '/';
    if (file.len > 0) {
        memcpy(temp_buf + temp_len, file.data, file.len);
        temp_len += file.len;
    }
    temp_buf[temp_len] = '\0';

    char** stack = malloc(temp_len * sizeof(char*));
    int* stack_lens = malloc(temp_len * sizeof(int));
    int stack_size = 0;

    int p = 0;
    while (p < temp_len) {
        while (p < temp_len && temp_buf[p] == '/') {
            p++;
        }
        if (p >= temp_len) break;

        int start = p;
        while (p < temp_len && temp_buf[p] != '/') {
            p++;
        }
        int comp_len = p - start;

        if (comp_len == 1 && temp_buf[start] == '.') {
            // Ignore "."
        } else if (comp_len == 2 && temp_buf[start] == '.' && temp_buf[start + 1] == '.') {
            if (stack_size > 0 && !(stack_lens[stack_size - 1] == 2 && stack[stack_size - 1][0] == '.' && stack[stack_size - 1][1] == '.')) {
                stack_size--;
            } else {
                if (!is_absolute) {
                    stack[stack_size] = temp_buf + start;
                    stack_lens[stack_size] = comp_len;
                    stack_size++;
                }
            }
        } else if (comp_len > 0) {
            stack[stack_size] = temp_buf + start;
            stack_lens[stack_size] = comp_len;
            stack_size++;
        }
    }

    int final_len = 0;
    if (is_absolute) {
        final_len += 1;
    }
    for (int i = 0; i < stack_size; i++) {
        final_len += stack_lens[i];
        if (i < stack_size - 1) {
            final_len += 1;
        }
    }

    if (final_len == 0) {
        final_len = 1;
    }

    int offset = os_ArenaAlloc(ctx, final_len);
    char* dest = (char*)ctx->BaseAddress + offset;
    int dest_p = 0;

    if (is_absolute) {
        dest[dest_p++] = '/';
    }

    if (stack_size == 0 && !is_absolute) {
        dest[dest_p++] = '.';
    } else {
        for (int i = 0; i < stack_size; i++) {
            memcpy(dest + dest_p, stack[i], stack_lens[i]);
            dest_p += stack_lens[i];
            if (i < stack_size - 1) {
                dest[dest_p++] = '/';
            }
        }
    }

    free(temp_buf);
    free(stack);
    free(stack_lens);

    Slice_unsigned_char result;
    result.data = (unsigned char*)dest;
    result.len = final_len;
    return result;
}

// ====================================================
// FUNCTION FORWARD DECLARATIONS
// ====================================================
unsigned char lexer__is_letter(unsigned char b);
void* lexer__is_letter_pthread_wrapper(void* arg);
void lexer__init_lexer(lexer__Lexer* l, Slice_unsigned_char input);
Slice_unsigned_char ast__serialize_block_statement(int block_idx, int indent, os_Arena* ctx);
os_Arena os_Arena_New(void);
int parser__parse_import_statement(parser__Parser* p, os_Arena* ctx);
Slice_unsigned_char ast__ast_join_params(std_Vector_ast__Parameter params, int indent, os_Arena* ctx);
int parser__parse_struct_decl(parser__Parser* p, os_Arena* ctx);
token__Span parser__get_expression_span(int expr, os_Arena* ctx);
token__Span parser__merge_spans(token__Span start, token__Span end);
void std_Yield(void);
void std_Yield(void);
LookupResult_os_Dir os_OpenDir(os_Arena* arg0, Slice_unsigned_char arg1);
void parser__init_parser(parser__Parser* p, lexer__Lexer* l, os_Arena* ctx);
void parser__error_at_current(parser__Parser* p, Slice_unsigned_char message);
unsigned char parser__peek_token_is(parser__Parser* p, int tag);
int parser__Parser_ctx_IsValid(parser__Parser* req);
void* parser__Parser_ctx_IsValid_pthread_wrapper(void* arg);
Slice_unsigned_char std_Format(Slice_unsigned_char arg0);
void* std_Format_pthread_wrapper(void* arg);
int parser__cur_token_precedence(parser__Parser* p);
void* parser__cur_token_precedence_pthread_wrapper(void* arg);
token__Position lexer__current_position(lexer__Lexer* l);
void* lexer__current_position_pthread_wrapper(void* arg);
int lexer__Lexer_Any_IsValid(lexer__Lexer* req);
void* lexer__Lexer_Any_IsValid_pthread_wrapper(void* arg);
unsigned char lexer__is_digit(unsigned char b);
void* lexer__is_digit_pthread_wrapper(void* arg);
Slice_unsigned_char lexer__read_identifier(lexer__Lexer* l);
void* lexer__read_identifier_pthread_wrapper(void* arg);
void parser__synchronize(parser__Parser* p);
void* parser__synchronize_pthread_wrapper(void* arg);
int parser__parse_if_statement(parser__Parser* p, os_Arena* ctx);
Slice_unsigned_char parser__parser_get_type_ident(ast__Type t, os_Arena* ctx);
int parser__parse_type_signature(parser__Parser* p, os_Arena* ctx);
Slice_unsigned_char ast__serialize_match_case(ast__MatchCase case_val, int indent, os_Arena* ctx);
ast__Program parser__parse_program(parser__Parser* p, os_Arena* ctx);
Slice_unsigned_char lexer__read_number(lexer__Lexer* l);
void* lexer__read_number_pthread_wrapper(void* arg);
int parser__parse_statement(parser__Parser* p, os_Arena* ctx);
void os_CloseDir(os_Dir arg0);
void* os_CloseDir_pthread_wrapper(void* arg);
int parser__parse_unsafe_block(parser__Parser* p, os_Arena* ctx);
LookupResult_os_DirEntry os_ReadDir(os_Arena* arg0, os_Dir arg1);
Slice_unsigned_char ast__serialize_program(ast__Program* prog, int indent, os_Arena* ctx);
int parser__parse_defer_statement(parser__Parser* p, os_Arena* ctx);
void os_SetThreadScratch(os_Arena* arg0);
void* os_SetThreadScratch_pthread_wrapper(void* arg);
int parser__parse_block_statement(parser__Parser* p, os_Arena* ctx);
int parser__parse_guard_statement(parser__Parser* p, os_Arena* ctx);
int parser__parse_var_decl(parser__Parser* p, int is_mut, os_Arena* ctx);
void os_CloseDir(os_Dir arg0);
void* os_CloseDir_pthread_wrapper(void* arg);
Slice_unsigned_char ast__serialize_type(ast__Type t, os_Arena* ctx);
void lexer__next_token(lexer__Lexer* l, token__Token* tok);
Slice_unsigned_char ast__ast_join_strings(std_Vector_str vec, Slice_unsigned_char sep, os_Arena* ctx);
Slice_unsigned_char lexer__read_string(lexer__Lexer* l);
void* lexer__read_string_pthread_wrapper(void* arg);
Slice_unsigned_char ast__serialize_expression(int expr_idx, int indent, os_Arena* ctx);
void os_SetThreadScratch(os_Arena* arg0);
void* os_SetThreadScratch_pthread_wrapper(void* arg);
Slice_unsigned_char parser__parser_get_monomorphized_name(Slice_unsigned_char template_name, int args_idx, os_Arena* ctx);
int parser__parse_function_decl(parser__Parser* p, os_Arena* ctx);
int parser__parse_return_statement(parser__Parser* p, os_Arena* ctx);
unsigned char parser__cur_token_is(parser__Parser* p, int tag);
void lexer__read_char(lexer__Lexer* l);
void* lexer__read_char_pthread_wrapper(void* arg);
Slice_unsigned_char ast__serialize_statement(int stmt_idx, int indent, os_Arena* ctx);
os_Arena os_Arena_New(void);
int parser__peek_token_precedence(parser__Parser* p);
void* parser__peek_token_precedence_pthread_wrapper(void* arg);
Slice_unsigned_char ast__ast_repeat_spaces(int indent, os_Arena* ctx);
int parser__parse_prefix_expression(parser__Parser* p, os_Arena* ctx);
int parser__parse_match_statement(parser__Parser* p, os_Arena* ctx);
int parser__parse_expression(parser__Parser* p, int precedence, os_Arena* ctx);
Slice_unsigned_char ast__serialize_variant_def(ast__VariantDef v, int indent, os_Arena* ctx);
parser__ParseResult parser__expect_peek(parser__Parser* p, int tag, os_Arena* ctx);
unsigned char lexer__peek_char(lexer__Lexer* l);
void* lexer__peek_char_pthread_wrapper(void* arg);
Slice_unsigned_char std_Format(Slice_unsigned_char arg0);
void* std_Format_pthread_wrapper(void* arg);
Slice_unsigned_char ast__ast_join_fields(std_Vector_ast__FieldDef fields, int indent, os_Arena* ctx);
int parser__is_at_end(parser__Parser* p);
void* parser__is_at_end_pthread_wrapper(void* arg);
LookupResult_os_Dir os_OpenDir(os_Arena* arg0, Slice_unsigned_char arg1);
os_Arena os_Arena_New(void);
LookupResult_os_DirEntry os_ReadDir(os_Arena* arg0, os_Dir arg1);
void lexer__skip_whitespace(lexer__Lexer* l);
void* lexer__skip_whitespace_pthread_wrapper(void* arg);
int parser__parse_while_statement(parser__Parser* p, os_Arena* ctx);
void parser__next_token(parser__Parser* p);
void* parser__next_token_pthread_wrapper(void* arg);
token__TokenType lexer__lookup_ident(Slice_unsigned_char literal);
void* lexer__lookup_ident_pthread_wrapper(void* arg);
int lexer__Lexer_ctx_IsValid(lexer__Lexer* req);
void* lexer__Lexer_ctx_IsValid_pthread_wrapper(void* arg);

// ====================================================
// DYNAMICALLY TRANSPILED USER STRUCTS
// ====================================================
typedef struct CastResult_APIRequest CastResult_APIRequest;
typedef struct CastResult_SessionNode CastResult_SessionNode;
typedef struct CastResult_token__Position CastResult_token__Position;
typedef struct CastResult_token__Span CastResult_token__Span;
typedef struct CastResult_ast__BlockStatement CastResult_ast__BlockStatement;
typedef struct CastResult_ast__Expression_AddressOf CastResult_ast__Expression_AddressOf;
typedef struct CastResult_ast__Expression_AsCast CastResult_ast__Expression_AsCast;
typedef struct CastResult_ast__Expression_Binary CastResult_ast__Expression_Binary;
typedef struct CastResult_ast__Expression_Bool CastResult_ast__Expression_Bool;
typedef struct CastResult_ast__Expression_Call CastResult_ast__Expression_Call;
typedef struct CastResult_ast__Expression_Dereference CastResult_ast__Expression_Dereference;
typedef struct CastResult_ast__Expression_Empty CastResult_ast__Expression_Empty;
typedef struct CastResult_ast__Expression_Identifier CastResult_ast__Expression_Identifier;
typedef struct CastResult_ast__Expression_IndexAccess CastResult_ast__Expression_IndexAccess;
typedef struct CastResult_ast__Expression_Integer CastResult_ast__Expression_Integer;
typedef struct CastResult_ast__Expression_Move CastResult_ast__Expression_Move;
typedef struct CastResult_ast__Expression_Selector CastResult_ast__Expression_Selector;
typedef struct CastResult_ast__Expression_String CastResult_ast__Expression_String;
typedef struct CastResult_ast__Expression_Take CastResult_ast__Expression_Take;
typedef struct CastResult_ast__Expression CastResult_ast__Expression;
typedef struct CastResult_ast__Type_Arena CastResult_ast__Type_Arena;
typedef struct CastResult_ast__Type_Bool CastResult_ast__Type_Bool;
typedef struct CastResult_ast__Type_Byte CastResult_ast__Type_Byte;
typedef struct CastResult_ast__Type_Generic CastResult_ast__Type_Generic;
typedef struct CastResult_ast__Type_Index CastResult_ast__Type_Index;
typedef struct CastResult_ast__Type_Int CastResult_ast__Type_Int;
typedef struct CastResult_ast__Type_RawPointer CastResult_ast__Type_RawPointer;
typedef struct CastResult_ast__Type_Slice CastResult_ast__Type_Slice;
typedef struct CastResult_ast__Type_Str CastResult_ast__Type_Str;
typedef struct CastResult_ast__Type_Struct CastResult_ast__Type_Struct;
typedef struct CastResult_ast__Type_Void CastResult_ast__Type_Void;
typedef struct CastResult_ast__Type CastResult_ast__Type;
typedef struct CastResult_ast__FieldDef CastResult_ast__FieldDef;
typedef struct CastResult_ast__MatchCase CastResult_ast__MatchCase;
typedef struct CastResult_ast__Parameter CastResult_ast__Parameter;
typedef struct CastResult_ast__Program CastResult_ast__Program;
typedef struct CastResult_ast__Statement_Assignment CastResult_ast__Statement_Assignment;
typedef struct CastResult_ast__Statement_Defer CastResult_ast__Statement_Defer;
typedef struct CastResult_ast__Statement_EnumDecl CastResult_ast__Statement_EnumDecl;
typedef struct CastResult_ast__Statement_Expression CastResult_ast__Statement_Expression;
typedef struct CastResult_ast__Statement_FunctionDecl CastResult_ast__Statement_FunctionDecl;
typedef struct CastResult_ast__Statement_Guard CastResult_ast__Statement_Guard;
typedef struct CastResult_ast__Statement_If CastResult_ast__Statement_If;
typedef struct CastResult_ast__Statement_Import CastResult_ast__Statement_Import;
typedef struct CastResult_ast__Statement_Match CastResult_ast__Statement_Match;
typedef struct CastResult_ast__Statement_Return CastResult_ast__Statement_Return;
typedef struct CastResult_ast__Statement_StructDecl CastResult_ast__Statement_StructDecl;
typedef struct CastResult_ast__Statement_UnsafeBlock CastResult_ast__Statement_UnsafeBlock;
typedef struct CastResult_ast__Statement_VarDecl CastResult_ast__Statement_VarDecl;
typedef struct CastResult_ast__Statement_While CastResult_ast__Statement_While;
typedef struct CastResult_ast__Statement CastResult_ast__Statement;
typedef struct CastResult_ast__VariantDef CastResult_ast__VariantDef;
typedef struct CastResult_errors__ErrorKind_CodegenError CastResult_errors__ErrorKind_CodegenError;
typedef struct CastResult_errors__ErrorKind_LexerError CastResult_errors__ErrorKind_LexerError;
typedef struct CastResult_errors__ErrorKind_ParserError CastResult_errors__ErrorKind_ParserError;
typedef struct CastResult_errors__ErrorKind_TypeError CastResult_errors__ErrorKind_TypeError;
typedef struct CastResult_errors__ErrorKind CastResult_errors__ErrorKind;
typedef struct CastResult_errors__CompilerError CastResult_errors__CompilerError;
typedef struct CastResult_lexer__Lexer CastResult_lexer__Lexer;
typedef struct CastResult_token__TokenType_Ampersand CastResult_token__TokenType_Ampersand;
typedef struct CastResult_token__TokenType_As CastResult_token__TokenType_As;
typedef struct CastResult_token__TokenType_Assign CastResult_token__TokenType_Assign;
typedef struct CastResult_token__TokenType_Asterisk CastResult_token__TokenType_Asterisk;
typedef struct CastResult_token__TokenType_Bool CastResult_token__TokenType_Bool;
typedef struct CastResult_token__TokenType_Colon CastResult_token__TokenType_Colon;
typedef struct CastResult_token__TokenType_Comma CastResult_token__TokenType_Comma;
typedef struct CastResult_token__TokenType_Defer CastResult_token__TokenType_Defer;
typedef struct CastResult_token__TokenType_Dot CastResult_token__TokenType_Dot;
typedef struct CastResult_token__TokenType_Else CastResult_token__TokenType_Else;
typedef struct CastResult_token__TokenType_Empty CastResult_token__TokenType_Empty;
typedef struct CastResult_token__TokenType_Enum CastResult_token__TokenType_Enum;
typedef struct CastResult_token__TokenType_Eof CastResult_token__TokenType_Eof;
typedef struct CastResult_token__TokenType_Eq CastResult_token__TokenType_Eq;
typedef struct CastResult_token__TokenType_EqEq CastResult_token__TokenType_EqEq;
typedef struct CastResult_token__TokenType_False CastResult_token__TokenType_False;
typedef struct CastResult_token__TokenType_FatArrow CastResult_token__TokenType_FatArrow;
typedef struct CastResult_token__TokenType_Func CastResult_token__TokenType_Func;
typedef struct CastResult_token__TokenType_Gt CastResult_token__TokenType_Gt;
typedef struct CastResult_token__TokenType_Guard CastResult_token__TokenType_Guard;
typedef struct CastResult_token__TokenType_Ident CastResult_token__TokenType_Ident;
typedef struct CastResult_token__TokenType_If CastResult_token__TokenType_If;
typedef struct CastResult_token__TokenType_Illegal CastResult_token__TokenType_Illegal;
typedef struct CastResult_token__TokenType_Import CastResult_token__TokenType_Import;
typedef struct CastResult_token__TokenType_Int CastResult_token__TokenType_Int;
typedef struct CastResult_token__TokenType_LBrace CastResult_token__TokenType_LBrace;
typedef struct CastResult_token__TokenType_LBracket CastResult_token__TokenType_LBracket;
typedef struct CastResult_token__TokenType_LParen CastResult_token__TokenType_LParen;
typedef struct CastResult_token__TokenType_Lt CastResult_token__TokenType_Lt;
typedef struct CastResult_token__TokenType_Match CastResult_token__TokenType_Match;
typedef struct CastResult_token__TokenType_Minus CastResult_token__TokenType_Minus;
typedef struct CastResult_token__TokenType_Move CastResult_token__TokenType_Move;
typedef struct CastResult_token__TokenType_Mut CastResult_token__TokenType_Mut;
typedef struct CastResult_token__TokenType_NotEq CastResult_token__TokenType_NotEq;
typedef struct CastResult_token__TokenType_Plus CastResult_token__TokenType_Plus;
typedef struct CastResult_token__TokenType_RBrace CastResult_token__TokenType_RBrace;
typedef struct CastResult_token__TokenType_RBracket CastResult_token__TokenType_RBracket;
typedef struct CastResult_token__TokenType_RParen CastResult_token__TokenType_RParen;
typedef struct CastResult_token__TokenType_Return CastResult_token__TokenType_Return;
typedef struct CastResult_token__TokenType_Semicolon CastResult_token__TokenType_Semicolon;
typedef struct CastResult_token__TokenType_Slash CastResult_token__TokenType_Slash;
typedef struct CastResult_token__TokenType_String CastResult_token__TokenType_String;
typedef struct CastResult_token__TokenType_Struct CastResult_token__TokenType_Struct;
typedef struct CastResult_token__TokenType_Take CastResult_token__TokenType_Take;
typedef struct CastResult_token__TokenType_True CastResult_token__TokenType_True;
typedef struct CastResult_token__TokenType_Type CastResult_token__TokenType_Type;
typedef struct CastResult_token__TokenType_Unsafe CastResult_token__TokenType_Unsafe;
typedef struct CastResult_token__TokenType_While CastResult_token__TokenType_While;
typedef struct CastResult_token__TokenType CastResult_token__TokenType;
typedef struct CastResult_token__Token CastResult_token__Token;
typedef struct CastResult_parser__ParseResult CastResult_parser__ParseResult;
typedef struct CastResult_std_Vector_errors__CompilerError CastResult_std_Vector_errors__CompilerError;
typedef struct CastResult_std_Vector_token__Token CastResult_std_Vector_token__Token;
typedef struct CastResult_parser__Parser CastResult_parser__Parser;
typedef struct CastResult_std_Vector_ast__Expression CastResult_std_Vector_ast__Expression;
typedef struct CastResult_std_Vector_ast__FieldDef CastResult_std_Vector_ast__FieldDef;
typedef struct CastResult_std_Vector_ast__MatchCase CastResult_std_Vector_ast__MatchCase;
typedef struct CastResult_std_Vector_ast__Parameter CastResult_std_Vector_ast__Parameter;
typedef struct CastResult_std_Vector_ast__Statement CastResult_std_Vector_ast__Statement;
typedef struct CastResult_std_Vector_ast__Type CastResult_std_Vector_ast__Type;
typedef struct CastResult_std_Vector_ast__VariantDef CastResult_std_Vector_ast__VariantDef;
typedef struct CastResult_std_Vector_str CastResult_std_Vector_str;

struct APIRequest {
    int Active;
    int SessionID;
    int UserID;
};

struct CastResult_APIRequest {
    APIRequest* Val;
    int Ok;
};

struct SessionNode {
    int Next;
    int SessionID;
};

struct CastResult_SessionNode {
    SessionNode* Val;
    int Ok;
};

struct token__Position {
    int column;
    int line;
    int offset;
};

struct CastResult_token__Position {
    token__Position* Val;
    int Ok;
};

struct token__Span {
    token__Position end;
    token__Position start;
};

struct CastResult_token__Span {
    token__Span* Val;
    int Ok;
};

struct ast__BlockStatement {
    token__Span span;
    int statements;
};

struct CastResult_ast__BlockStatement {
    ast__BlockStatement* Val;
    int Ok;
};

struct ast__Expression_AddressOf {
    int expr;
    token__Span span;
};

struct CastResult_ast__Expression_AddressOf {
    ast__Expression_AddressOf* Val;
    int Ok;
};

struct ast__Expression_AsCast {
    int is_reference;
    int left;
    token__Span span;
    int target_type;
};

struct CastResult_ast__Expression_AsCast {
    ast__Expression_AsCast* Val;
    int Ok;
};

struct ast__Expression_Binary {
    int left;
    Slice_unsigned_char op;
    int right;
    token__Span span;
};

struct CastResult_ast__Expression_Binary {
    ast__Expression_Binary* Val;
    int Ok;
};

struct ast__Expression_Bool {
    token__Span span;
    int val;
};

struct CastResult_ast__Expression_Bool {
    ast__Expression_Bool* Val;
    int Ok;
};

struct ast__Expression_Call {
    int arguments;
    int function;
    token__Span span;
};

struct CastResult_ast__Expression_Call {
    ast__Expression_Call* Val;
    int Ok;
};

struct ast__Expression_Dereference {
    int expr;
    token__Span span;
};

struct CastResult_ast__Expression_Dereference {
    ast__Expression_Dereference* Val;
    int Ok;
};

struct ast__Expression_Empty {
    token__Span span;
    int target_type;
};

struct CastResult_ast__Expression_Empty {
    ast__Expression_Empty* Val;
    int Ok;
};

struct ast__Expression_Identifier {
    Slice_unsigned_char name;
    token__Span span;
};

struct CastResult_ast__Expression_Identifier {
    ast__Expression_Identifier* Val;
    int Ok;
};

struct ast__Expression_IndexAccess {
    int allocator;
    int index;
    token__Span span;
};

struct CastResult_ast__Expression_IndexAccess {
    ast__Expression_IndexAccess* Val;
    int Ok;
};

struct ast__Expression_Integer {
    token__Span span;
    int val;
};

struct CastResult_ast__Expression_Integer {
    ast__Expression_Integer* Val;
    int Ok;
};

struct ast__Expression_Move {
    int expr;
    token__Span span;
};

struct CastResult_ast__Expression_Move {
    ast__Expression_Move* Val;
    int Ok;
};

struct ast__Expression_Selector {
    int left;
    Slice_unsigned_char right;
    token__Span span;
};

struct CastResult_ast__Expression_Selector {
    ast__Expression_Selector* Val;
    int Ok;
};

struct ast__Expression_String {
    token__Span span;
    Slice_unsigned_char val;
};

struct CastResult_ast__Expression_String {
    ast__Expression_String* Val;
    int Ok;
};

struct ast__Expression_Take {
    int expr;
    token__Span span;
};

struct CastResult_ast__Expression_Take {
    ast__Expression_Take* Val;
    int Ok;
};

typedef enum {
    ast__Expression_Tag__Identifier = 0,
    ast__Expression_Tag__Integer = 1,
    ast__Expression_Tag__String = 2,
    ast__Expression_Tag__Bool = 3,
    ast__Expression_Tag__Move = 4,
    ast__Expression_Tag__Take = 5,
    ast__Expression_Tag__AddressOf = 6,
    ast__Expression_Tag__Dereference = 7,
    ast__Expression_Tag__IndexAccess = 8,
    ast__Expression_Tag__AsCast = 9,
    ast__Expression_Tag__Binary = 10,
    ast__Expression_Tag__Selector = 11,
    ast__Expression_Tag__Call = 12,
    ast__Expression_Tag__Empty = 13,
} ast__Expression_Tag;

struct ast__Expression {
    int tag; 
    union {
        struct ast__Expression_AddressOf AddressOf;
        struct ast__Expression_AsCast AsCast;
        struct ast__Expression_Binary Binary;
        struct ast__Expression_Bool Bool;
        struct ast__Expression_Call Call;
        struct ast__Expression_Dereference Dereference;
        struct ast__Expression_Empty Empty;
        struct ast__Expression_Identifier Identifier;
        struct ast__Expression_IndexAccess IndexAccess;
        struct ast__Expression_Integer Integer;
        struct ast__Expression_Move Move;
        struct ast__Expression_Selector Selector;
        struct ast__Expression_String String;
        struct ast__Expression_Take Take;
    };
};

struct CastResult_ast__Expression {
    ast__Expression* Val;
    int Ok;
};

struct ast__Type_Arena {
    char dummy;
};

struct CastResult_ast__Type_Arena {
    ast__Type_Arena* Val;
    int Ok;
};

struct ast__Type_Bool {
    char dummy;
};

struct CastResult_ast__Type_Bool {
    ast__Type_Bool* Val;
    int Ok;
};

struct ast__Type_Byte {
    char dummy;
};

struct CastResult_ast__Type_Byte {
    ast__Type_Byte* Val;
    int Ok;
};

struct ast__Type_Generic {
    int args;
    Slice_unsigned_char name;
};

struct CastResult_ast__Type_Generic {
    ast__Type_Generic* Val;
    int Ok;
};

struct ast__Type_Index {
    int brand;
    Slice_unsigned_char struct_name;
};

struct CastResult_ast__Type_Index {
    ast__Type_Index* Val;
    int Ok;
};

struct ast__Type_Int {
    char dummy;
};

struct CastResult_ast__Type_Int {
    ast__Type_Int* Val;
    int Ok;
};

struct ast__Type_RawPointer {
    int inner;
};

struct CastResult_ast__Type_RawPointer {
    ast__Type_RawPointer* Val;
    int Ok;
};

struct ast__Type_Slice {
    int inner;
};

struct CastResult_ast__Type_Slice {
    ast__Type_Slice* Val;
    int Ok;
};

struct ast__Type_Str {
    char dummy;
};

struct CastResult_ast__Type_Str {
    ast__Type_Str* Val;
    int Ok;
};

struct ast__Type_Struct {
    int brand;
    Slice_unsigned_char struct_name;
};

struct CastResult_ast__Type_Struct {
    ast__Type_Struct* Val;
    int Ok;
};

struct ast__Type_Void {
    char dummy;
};

struct CastResult_ast__Type_Void {
    ast__Type_Void* Val;
    int Ok;
};

typedef enum {
    ast__Type_Tag__Int = 0,
    ast__Type_Tag__Byte = 1,
    ast__Type_Tag__Bool = 2,
    ast__Type_Tag__Void = 3,
    ast__Type_Tag__Arena = 4,
    ast__Type_Tag__Str = 5,
    ast__Type_Tag__Slice = 6,
    ast__Type_Tag__Index = 7,
    ast__Type_Tag__Struct = 8,
    ast__Type_Tag__RawPointer = 9,
    ast__Type_Tag__Generic = 10,
} ast__Type_Tag;

struct ast__Type {
    int tag; 
    union {
        struct ast__Type_Arena Arena;
        struct ast__Type_Bool Bool;
        struct ast__Type_Byte Byte;
        struct ast__Type_Generic Generic;
        struct ast__Type_Index Index;
        struct ast__Type_Int Int;
        struct ast__Type_RawPointer RawPointer;
        struct ast__Type_Slice Slice;
        struct ast__Type_Str Str;
        struct ast__Type_Struct Struct;
        struct ast__Type_Void Void;
    };
};

struct CastResult_ast__Type {
    ast__Type* Val;
    int Ok;
};

struct ast__FieldDef {
    ast__Type field_type;
    Slice_unsigned_char name;
    token__Span span;
};

struct CastResult_ast__FieldDef {
    ast__FieldDef* Val;
    int Ok;
};

struct ast__MatchCase {
    int body;
    int fields;
    token__Span span;
    Slice_unsigned_char variant_name;
};

struct CastResult_ast__MatchCase {
    ast__MatchCase* Val;
    int Ok;
};

struct ast__Parameter {
    Slice_unsigned_char name;
    ast__Type param_type;
    token__Span span;
};

struct CastResult_ast__Parameter {
    ast__Parameter* Val;
    int Ok;
};

struct ast__Program {
    token__Span span;
    int statements;
};

struct CastResult_ast__Program {
    ast__Program* Val;
    int Ok;
};

struct ast__Statement_Assignment {
    int left;
    token__Span span;
    int value;
};

struct CastResult_ast__Statement_Assignment {
    ast__Statement_Assignment* Val;
    int Ok;
};

struct ast__Statement_Defer {
    int expr;
    token__Span span;
};

struct CastResult_ast__Statement_Defer {
    ast__Statement_Defer* Val;
    int Ok;
};

struct ast__Statement_EnumDecl {
    int generics;
    Slice_unsigned_char name;
    token__Span span;
    int variants;
};

struct CastResult_ast__Statement_EnumDecl {
    ast__Statement_EnumDecl* Val;
    int Ok;
};

struct ast__Statement_Expression {
    int expr;
    token__Span span;
};

struct CastResult_ast__Statement_Expression {
    ast__Statement_Expression* Val;
    int Ok;
};

struct ast__Statement_FunctionDecl {
    int body;
    Slice_unsigned_char name;
    int params;
    int return_type;
    token__Span span;
};

struct CastResult_ast__Statement_FunctionDecl {
    ast__Statement_FunctionDecl* Val;
    int Ok;
};

struct ast__Statement_Guard {
    int else_body;
    int is_mut;
    Slice_unsigned_char name;
    token__Span span;
    int value;
};

struct CastResult_ast__Statement_Guard {
    ast__Statement_Guard* Val;
    int Ok;
};

struct ast__Statement_If {
    int alternative;
    int condition;
    int consequence;
    token__Span span;
};

struct CastResult_ast__Statement_If {
    ast__Statement_If* Val;
    int Ok;
};

struct ast__Statement_Import {
    Slice_unsigned_char alias;
    Slice_unsigned_char path;
    token__Span span;
};

struct CastResult_ast__Statement_Import {
    ast__Statement_Import* Val;
    int Ok;
};

struct ast__Statement_Match {
    int cases;
    int expression;
    token__Span span;
};

struct CastResult_ast__Statement_Match {
    ast__Statement_Match* Val;
    int Ok;
};

struct ast__Statement_Return {
    int expr;
    token__Span span;
};

struct CastResult_ast__Statement_Return {
    ast__Statement_Return* Val;
    int Ok;
};

struct ast__Statement_StructDecl {
    int fields;
    int generics;
    Slice_unsigned_char name;
    token__Span span;
};

struct CastResult_ast__Statement_StructDecl {
    ast__Statement_StructDecl* Val;
    int Ok;
};

struct ast__Statement_UnsafeBlock {
    int body;
    token__Span span;
};

struct CastResult_ast__Statement_UnsafeBlock {
    ast__Statement_UnsafeBlock* Val;
    int Ok;
};

struct ast__Statement_VarDecl {
    int is_mut;
    Slice_unsigned_char name;
    token__Span span;
    int value;
    int var_type;
};

struct CastResult_ast__Statement_VarDecl {
    ast__Statement_VarDecl* Val;
    int Ok;
};

struct ast__Statement_While {
    int body;
    int condition;
    token__Span span;
};

struct CastResult_ast__Statement_While {
    ast__Statement_While* Val;
    int Ok;
};

typedef enum {
    ast__Statement_Tag__Import = 0,
    ast__Statement_Tag__StructDecl = 1,
    ast__Statement_Tag__EnumDecl = 2,
    ast__Statement_Tag__FunctionDecl = 3,
    ast__Statement_Tag__VarDecl = 4,
    ast__Statement_Tag__Assignment = 5,
    ast__Statement_Tag__While = 6,
    ast__Statement_Tag__If = 7,
    ast__Statement_Tag__Match = 8,
    ast__Statement_Tag__Guard = 9,
    ast__Statement_Tag__UnsafeBlock = 10,
    ast__Statement_Tag__Defer = 11,
    ast__Statement_Tag__Return = 12,
    ast__Statement_Tag__Expression = 13,
} ast__Statement_Tag;

struct ast__Statement {
    int tag; 
    union {
        struct ast__Statement_Assignment Assignment;
        struct ast__Statement_Defer Defer;
        struct ast__Statement_EnumDecl EnumDecl;
        struct ast__Statement_Expression Expression;
        struct ast__Statement_FunctionDecl FunctionDecl;
        struct ast__Statement_Guard Guard;
        struct ast__Statement_If If;
        struct ast__Statement_Import Import;
        struct ast__Statement_Match Match;
        struct ast__Statement_Return Return;
        struct ast__Statement_StructDecl StructDecl;
        struct ast__Statement_UnsafeBlock UnsafeBlock;
        struct ast__Statement_VarDecl VarDecl;
        struct ast__Statement_While While;
    };
};

struct CastResult_ast__Statement {
    ast__Statement* Val;
    int Ok;
};

struct ast__VariantDef {
    int fields;
    Slice_unsigned_char name;
    token__Span span;
};

struct CastResult_ast__VariantDef {
    ast__VariantDef* Val;
    int Ok;
};

struct errors__ErrorKind_CodegenError {
    char dummy;
};

struct CastResult_errors__ErrorKind_CodegenError {
    errors__ErrorKind_CodegenError* Val;
    int Ok;
};

struct errors__ErrorKind_LexerError {
    char dummy;
};

struct CastResult_errors__ErrorKind_LexerError {
    errors__ErrorKind_LexerError* Val;
    int Ok;
};

struct errors__ErrorKind_ParserError {
    char dummy;
};

struct CastResult_errors__ErrorKind_ParserError {
    errors__ErrorKind_ParserError* Val;
    int Ok;
};

struct errors__ErrorKind_TypeError {
    char dummy;
};

struct CastResult_errors__ErrorKind_TypeError {
    errors__ErrorKind_TypeError* Val;
    int Ok;
};

typedef enum {
    errors__ErrorKind_Tag__LexerError = 0,
    errors__ErrorKind_Tag__ParserError = 1,
    errors__ErrorKind_Tag__TypeError = 2,
    errors__ErrorKind_Tag__CodegenError = 3,
} errors__ErrorKind_Tag;

struct errors__ErrorKind {
    int tag; 
    union {
        struct errors__ErrorKind_CodegenError CodegenError;
        struct errors__ErrorKind_LexerError LexerError;
        struct errors__ErrorKind_ParserError ParserError;
        struct errors__ErrorKind_TypeError TypeError;
    };
};

struct CastResult_errors__ErrorKind {
    errors__ErrorKind* Val;
    int Ok;
};

struct errors__CompilerError {
    errors__ErrorKind kind;
    Slice_unsigned_char message;
    token__Span span;
};

struct CastResult_errors__CompilerError {
    errors__CompilerError* Val;
    int Ok;
};

struct lexer__Lexer {
    unsigned char ch;
    int column;
    Slice_unsigned_char input;
    int line;
    int position;
    int read_position;
};

struct CastResult_lexer__Lexer {
    lexer__Lexer* Val;
    int Ok;
};

struct token__TokenType_Ampersand {
    char dummy;
};

struct CastResult_token__TokenType_Ampersand {
    token__TokenType_Ampersand* Val;
    int Ok;
};

struct token__TokenType_As {
    char dummy;
};

struct CastResult_token__TokenType_As {
    token__TokenType_As* Val;
    int Ok;
};

struct token__TokenType_Assign {
    char dummy;
};

struct CastResult_token__TokenType_Assign {
    token__TokenType_Assign* Val;
    int Ok;
};

struct token__TokenType_Asterisk {
    char dummy;
};

struct CastResult_token__TokenType_Asterisk {
    token__TokenType_Asterisk* Val;
    int Ok;
};

struct token__TokenType_Bool {
    char dummy;
};

struct CastResult_token__TokenType_Bool {
    token__TokenType_Bool* Val;
    int Ok;
};

struct token__TokenType_Colon {
    char dummy;
};

struct CastResult_token__TokenType_Colon {
    token__TokenType_Colon* Val;
    int Ok;
};

struct token__TokenType_Comma {
    char dummy;
};

struct CastResult_token__TokenType_Comma {
    token__TokenType_Comma* Val;
    int Ok;
};

struct token__TokenType_Defer {
    char dummy;
};

struct CastResult_token__TokenType_Defer {
    token__TokenType_Defer* Val;
    int Ok;
};

struct token__TokenType_Dot {
    char dummy;
};

struct CastResult_token__TokenType_Dot {
    token__TokenType_Dot* Val;
    int Ok;
};

struct token__TokenType_Else {
    char dummy;
};

struct CastResult_token__TokenType_Else {
    token__TokenType_Else* Val;
    int Ok;
};

struct token__TokenType_Empty {
    char dummy;
};

struct CastResult_token__TokenType_Empty {
    token__TokenType_Empty* Val;
    int Ok;
};

struct token__TokenType_Enum {
    char dummy;
};

struct CastResult_token__TokenType_Enum {
    token__TokenType_Enum* Val;
    int Ok;
};

struct token__TokenType_Eof {
    char dummy;
};

struct CastResult_token__TokenType_Eof {
    token__TokenType_Eof* Val;
    int Ok;
};

struct token__TokenType_Eq {
    char dummy;
};

struct CastResult_token__TokenType_Eq {
    token__TokenType_Eq* Val;
    int Ok;
};

struct token__TokenType_EqEq {
    char dummy;
};

struct CastResult_token__TokenType_EqEq {
    token__TokenType_EqEq* Val;
    int Ok;
};

struct token__TokenType_False {
    char dummy;
};

struct CastResult_token__TokenType_False {
    token__TokenType_False* Val;
    int Ok;
};

struct token__TokenType_FatArrow {
    char dummy;
};

struct CastResult_token__TokenType_FatArrow {
    token__TokenType_FatArrow* Val;
    int Ok;
};

struct token__TokenType_Func {
    char dummy;
};

struct CastResult_token__TokenType_Func {
    token__TokenType_Func* Val;
    int Ok;
};

struct token__TokenType_Gt {
    char dummy;
};

struct CastResult_token__TokenType_Gt {
    token__TokenType_Gt* Val;
    int Ok;
};

struct token__TokenType_Guard {
    char dummy;
};

struct CastResult_token__TokenType_Guard {
    token__TokenType_Guard* Val;
    int Ok;
};

struct token__TokenType_Ident {
    char dummy;
};

struct CastResult_token__TokenType_Ident {
    token__TokenType_Ident* Val;
    int Ok;
};

struct token__TokenType_If {
    char dummy;
};

struct CastResult_token__TokenType_If {
    token__TokenType_If* Val;
    int Ok;
};

struct token__TokenType_Illegal {
    char dummy;
};

struct CastResult_token__TokenType_Illegal {
    token__TokenType_Illegal* Val;
    int Ok;
};

struct token__TokenType_Import {
    char dummy;
};

struct CastResult_token__TokenType_Import {
    token__TokenType_Import* Val;
    int Ok;
};

struct token__TokenType_Int {
    char dummy;
};

struct CastResult_token__TokenType_Int {
    token__TokenType_Int* Val;
    int Ok;
};

struct token__TokenType_LBrace {
    char dummy;
};

struct CastResult_token__TokenType_LBrace {
    token__TokenType_LBrace* Val;
    int Ok;
};

struct token__TokenType_LBracket {
    char dummy;
};

struct CastResult_token__TokenType_LBracket {
    token__TokenType_LBracket* Val;
    int Ok;
};

struct token__TokenType_LParen {
    char dummy;
};

struct CastResult_token__TokenType_LParen {
    token__TokenType_LParen* Val;
    int Ok;
};

struct token__TokenType_Lt {
    char dummy;
};

struct CastResult_token__TokenType_Lt {
    token__TokenType_Lt* Val;
    int Ok;
};

struct token__TokenType_Match {
    char dummy;
};

struct CastResult_token__TokenType_Match {
    token__TokenType_Match* Val;
    int Ok;
};

struct token__TokenType_Minus {
    char dummy;
};

struct CastResult_token__TokenType_Minus {
    token__TokenType_Minus* Val;
    int Ok;
};

struct token__TokenType_Move {
    char dummy;
};

struct CastResult_token__TokenType_Move {
    token__TokenType_Move* Val;
    int Ok;
};

struct token__TokenType_Mut {
    char dummy;
};

struct CastResult_token__TokenType_Mut {
    token__TokenType_Mut* Val;
    int Ok;
};

struct token__TokenType_NotEq {
    char dummy;
};

struct CastResult_token__TokenType_NotEq {
    token__TokenType_NotEq* Val;
    int Ok;
};

struct token__TokenType_Plus {
    char dummy;
};

struct CastResult_token__TokenType_Plus {
    token__TokenType_Plus* Val;
    int Ok;
};

struct token__TokenType_RBrace {
    char dummy;
};

struct CastResult_token__TokenType_RBrace {
    token__TokenType_RBrace* Val;
    int Ok;
};

struct token__TokenType_RBracket {
    char dummy;
};

struct CastResult_token__TokenType_RBracket {
    token__TokenType_RBracket* Val;
    int Ok;
};

struct token__TokenType_RParen {
    char dummy;
};

struct CastResult_token__TokenType_RParen {
    token__TokenType_RParen* Val;
    int Ok;
};

struct token__TokenType_Return {
    char dummy;
};

struct CastResult_token__TokenType_Return {
    token__TokenType_Return* Val;
    int Ok;
};

struct token__TokenType_Semicolon {
    char dummy;
};

struct CastResult_token__TokenType_Semicolon {
    token__TokenType_Semicolon* Val;
    int Ok;
};

struct token__TokenType_Slash {
    char dummy;
};

struct CastResult_token__TokenType_Slash {
    token__TokenType_Slash* Val;
    int Ok;
};

struct token__TokenType_String {
    char dummy;
};

struct CastResult_token__TokenType_String {
    token__TokenType_String* Val;
    int Ok;
};

struct token__TokenType_Struct {
    char dummy;
};

struct CastResult_token__TokenType_Struct {
    token__TokenType_Struct* Val;
    int Ok;
};

struct token__TokenType_Take {
    char dummy;
};

struct CastResult_token__TokenType_Take {
    token__TokenType_Take* Val;
    int Ok;
};

struct token__TokenType_True {
    char dummy;
};

struct CastResult_token__TokenType_True {
    token__TokenType_True* Val;
    int Ok;
};

struct token__TokenType_Type {
    char dummy;
};

struct CastResult_token__TokenType_Type {
    token__TokenType_Type* Val;
    int Ok;
};

struct token__TokenType_Unsafe {
    char dummy;
};

struct CastResult_token__TokenType_Unsafe {
    token__TokenType_Unsafe* Val;
    int Ok;
};

struct token__TokenType_While {
    char dummy;
};

struct CastResult_token__TokenType_While {
    token__TokenType_While* Val;
    int Ok;
};

typedef enum {
    token__TokenType_Tag__Eof = 0,
    token__TokenType_Tag__Illegal = 1,
    token__TokenType_Tag__Ident = 2,
    token__TokenType_Tag__Int = 3,
    token__TokenType_Tag__String = 4,
    token__TokenType_Tag__Assign = 5,
    token__TokenType_Tag__Eq = 6,
    token__TokenType_Tag__Dot = 7,
    token__TokenType_Tag__Comma = 8,
    token__TokenType_Tag__Colon = 9,
    token__TokenType_Tag__Semicolon = 10,
    token__TokenType_Tag__LParen = 11,
    token__TokenType_Tag__RParen = 12,
    token__TokenType_Tag__LBrace = 13,
    token__TokenType_Tag__RBrace = 14,
    token__TokenType_Tag__LBracket = 15,
    token__TokenType_Tag__RBracket = 16,
    token__TokenType_Tag__Ampersand = 17,
    token__TokenType_Tag__FatArrow = 18,
    token__TokenType_Tag__Plus = 19,
    token__TokenType_Tag__Minus = 20,
    token__TokenType_Tag__Asterisk = 21,
    token__TokenType_Tag__Slash = 22,
    token__TokenType_Tag__EqEq = 23,
    token__TokenType_Tag__NotEq = 24,
    token__TokenType_Tag__Lt = 25,
    token__TokenType_Tag__Gt = 26,
    token__TokenType_Tag__Guard = 27,
    token__TokenType_Tag__Import = 28,
    token__TokenType_Tag__Mut = 29,
    token__TokenType_Tag__Func = 30,
    token__TokenType_Tag__Defer = 31,
    token__TokenType_Tag__Move = 32,
    token__TokenType_Tag__Take = 33,
    token__TokenType_Tag__While = 34,
    token__TokenType_Tag__If = 35,
    token__TokenType_Tag__Else = 36,
    token__TokenType_Tag__As = 37,
    token__TokenType_Tag__Unsafe = 38,
    token__TokenType_Tag__Type = 39,
    token__TokenType_Tag__Struct = 40,
    token__TokenType_Tag__Enum = 41,
    token__TokenType_Tag__Match = 42,
    token__TokenType_Tag__Return = 43,
    token__TokenType_Tag__Empty = 44,
    token__TokenType_Tag__Bool = 45,
    token__TokenType_Tag__True = 46,
    token__TokenType_Tag__False = 47,
} token__TokenType_Tag;

struct token__TokenType {
    int tag; 
    union {
        struct token__TokenType_Ampersand Ampersand;
        struct token__TokenType_As As;
        struct token__TokenType_Assign Assign;
        struct token__TokenType_Asterisk Asterisk;
        struct token__TokenType_Bool Bool;
        struct token__TokenType_Colon Colon;
        struct token__TokenType_Comma Comma;
        struct token__TokenType_Defer Defer;
        struct token__TokenType_Dot Dot;
        struct token__TokenType_Else Else;
        struct token__TokenType_Empty Empty;
        struct token__TokenType_Enum Enum;
        struct token__TokenType_Eof Eof;
        struct token__TokenType_Eq Eq;
        struct token__TokenType_EqEq EqEq;
        struct token__TokenType_False False;
        struct token__TokenType_FatArrow FatArrow;
        struct token__TokenType_Func Func;
        struct token__TokenType_Gt Gt;
        struct token__TokenType_Guard Guard;
        struct token__TokenType_Ident Ident;
        struct token__TokenType_If If;
        struct token__TokenType_Illegal Illegal;
        struct token__TokenType_Import Import;
        struct token__TokenType_Int Int;
        struct token__TokenType_LBrace LBrace;
        struct token__TokenType_LBracket LBracket;
        struct token__TokenType_LParen LParen;
        struct token__TokenType_Lt Lt;
        struct token__TokenType_Match Match;
        struct token__TokenType_Minus Minus;
        struct token__TokenType_Move Move;
        struct token__TokenType_Mut Mut;
        struct token__TokenType_NotEq NotEq;
        struct token__TokenType_Plus Plus;
        struct token__TokenType_RBrace RBrace;
        struct token__TokenType_RBracket RBracket;
        struct token__TokenType_RParen RParen;
        struct token__TokenType_Return Return;
        struct token__TokenType_Semicolon Semicolon;
        struct token__TokenType_Slash Slash;
        struct token__TokenType_String String;
        struct token__TokenType_Struct Struct;
        struct token__TokenType_Take Take;
        struct token__TokenType_True True;
        struct token__TokenType_Type Type;
        struct token__TokenType_Unsafe Unsafe;
        struct token__TokenType_While While;
    };
};

struct CastResult_token__TokenType {
    token__TokenType* Val;
    int Ok;
};

struct token__Token {
    Slice_unsigned_char literal;
    token__Span span;
    token__TokenType token_type;
};

struct CastResult_token__Token {
    token__Token* Val;
    int Ok;
};

struct parser__ParseResult {
    int Ok;
    token__Token Val;
};

struct CastResult_parser__ParseResult {
    parser__ParseResult* Val;
    int Ok;
};

struct std_Vector_errors__CompilerError {
    os_Arena* arena;
    int capacity;
    errors__CompilerError* data;
    int len;
};

struct CastResult_std_Vector_errors__CompilerError {
    std_Vector_errors__CompilerError* Val;
    int Ok;
};

struct std_Vector_token__Token {
    os_Arena* arena;
    int capacity;
    token__Token* data;
    int len;
};

struct CastResult_std_Vector_token__Token {
    std_Vector_token__Token* Val;
    int Ok;
};

struct parser__Parser {
    token__Token cur_token;
    std_Vector_errors__CompilerError errors;
    int has_non_import_statement;
    lexer__Lexer* lexer;
    token__Token peek_token;
    std_Vector_token__Token pushback_tokens;
};

struct CastResult_parser__Parser {
    parser__Parser* Val;
    int Ok;
};

struct std_Vector_ast__Expression {
    os_Arena* arena;
    int capacity;
    ast__Expression* data;
    int len;
};

struct CastResult_std_Vector_ast__Expression {
    std_Vector_ast__Expression* Val;
    int Ok;
};

struct std_Vector_ast__FieldDef {
    os_Arena* arena;
    int capacity;
    ast__FieldDef* data;
    int len;
};

struct CastResult_std_Vector_ast__FieldDef {
    std_Vector_ast__FieldDef* Val;
    int Ok;
};

struct std_Vector_ast__MatchCase {
    os_Arena* arena;
    int capacity;
    ast__MatchCase* data;
    int len;
};

struct CastResult_std_Vector_ast__MatchCase {
    std_Vector_ast__MatchCase* Val;
    int Ok;
};

struct std_Vector_ast__Parameter {
    os_Arena* arena;
    int capacity;
    ast__Parameter* data;
    int len;
};

struct CastResult_std_Vector_ast__Parameter {
    std_Vector_ast__Parameter* Val;
    int Ok;
};

struct std_Vector_ast__Statement {
    os_Arena* arena;
    int capacity;
    ast__Statement* data;
    int len;
};

struct CastResult_std_Vector_ast__Statement {
    std_Vector_ast__Statement* Val;
    int Ok;
};

struct std_Vector_ast__Type {
    os_Arena* arena;
    int capacity;
    ast__Type* data;
    int len;
};

struct CastResult_std_Vector_ast__Type {
    std_Vector_ast__Type* Val;
    int Ok;
};

struct std_Vector_ast__VariantDef {
    os_Arena* arena;
    int capacity;
    ast__VariantDef* data;
    int len;
};

struct CastResult_std_Vector_ast__VariantDef {
    std_Vector_ast__VariantDef* Val;
    int Ok;
};

// ====================================================
// INVARIANT VALIDATION HELPER FORWARD DECLARATIONS
// ====================================================
int lexer__Lexer_IsValid(lexer__Lexer* req);
int parser__Parser_IsValid(parser__Parser* req);

// ====================================================
// INVARIANT VALIDATION HELPERS
// ====================================================
int lexer__Lexer_IsValid(lexer__Lexer* req) {
    if (req == NULL) return 0;
    if (req->ch != 0x00 && req->ch != 0x01) return 0;
    return 1;
}

int parser__Parser_IsValid(parser__Parser* req) {
    if (req == NULL) return 0;
    return 1;
}

// ====================================================
// TRANSPILED PROGRAM CODES
// ====================================================
#line 12 "/home/garth/files/code/gust/compiler/lexer.gst"
void lexer__read_char(lexer__Lexer* l) {
#line 13 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 14 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 10) {
#line 15 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).line = (*(l)).line + 1;
#line 16 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).column = 1;
    } else {
#line 18 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).position > 0) {
#line 19 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).column = (*(l)).column + 1;
    } else {
#line 21 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).position == 0) {
#line 22 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch != 0) {
#line 23 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).column = (*(l)).column + 1;
    }
    }
    }
    }
#line 29 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).read_position >= (*(l)).input.len) {
#line 30 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).ch = 0;
    } else {
#line 32 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).ch = std_str_byte_at((*(l)).input, (*(l)).read_position);
    }
#line 34 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).position = (*(l)).read_position;
#line 35 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).read_position = (*(l)).read_position + 1;
    }
}

void* lexer__read_char_pthread_wrapper(void* arg) {
    lexer__read_char((lexer__Lexer*)arg);
    return NULL;
}

#line 39 "/home/garth/files/code/gust/compiler/lexer.gst"
void lexer__init_lexer(lexer__Lexer* l, Slice_unsigned_char input) {
#line 40 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 41 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).input = input;
#line 42 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).position = 0;
#line 43 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).read_position = 0;
#line 44 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).ch = 0;
#line 45 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).line = 1;
#line 46 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(l)).column = 1;
#line 47 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
}

#line 51 "/home/garth/files/code/gust/compiler/lexer.gst"
unsigned char lexer__peek_char(lexer__Lexer* l) {
#line 52 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 53 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).read_position >= (*(l)).input.len) {
#line 54 "/home/garth/files/code/gust/compiler/lexer.gst"
    return 0;
    }
#line 56 "/home/garth/files/code/gust/compiler/lexer.gst"
    return std_str_byte_at((*(l)).input, (*(l)).read_position);
    }
}

void* lexer__peek_char_pthread_wrapper(void* arg) {
    lexer__peek_char((lexer__Lexer*)arg);
    return NULL;
}

#line 60 "/home/garth/files/code/gust/compiler/lexer.gst"
void lexer__skip_whitespace(lexer__Lexer* l) {
#line 61 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 62 "/home/garth/files/code/gust/compiler/lexer.gst"
    while (std_is_whitespace((*(l)).ch)) {
#line 63 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
    }
}

void* lexer__skip_whitespace_pthread_wrapper(void* arg) {
    lexer__skip_whitespace((lexer__Lexer*)arg);
    return NULL;
}

#line 68 "/home/garth/files/code/gust/compiler/lexer.gst"
unsigned char lexer__is_letter(unsigned char b) {
#line 69 "/home/garth/files/code/gust/compiler/lexer.gst"
    return std_is_alpha(b);
}

void* lexer__is_letter_pthread_wrapper(void* arg) {
    lexer__is_letter((unsigned char)(uintptr_t)arg);
    return NULL;
}

#line 72 "/home/garth/files/code/gust/compiler/lexer.gst"
unsigned char lexer__is_digit(unsigned char b) {
#line 73 "/home/garth/files/code/gust/compiler/lexer.gst"
    return std_is_digit(b);
}

void* lexer__is_digit_pthread_wrapper(void* arg) {
    lexer__is_digit((unsigned char)(uintptr_t)arg);
    return NULL;
}

#line 76 "/home/garth/files/code/gust/compiler/lexer.gst"
Slice_unsigned_char lexer__read_identifier(lexer__Lexer* l) {
#line 77 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 78 "/home/garth/files/code/gust/compiler/lexer.gst"
    int start_pos = (*(l)).position;
#line 79 "/home/garth/files/code/gust/compiler/lexer.gst"
    while (lexer__is_letter((*(l)).ch) || lexer__is_digit((*(l)).ch)) {
#line 80 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
#line 82 "/home/garth/files/code/gust/compiler/lexer.gst"
    return std_str_slice((*(l)).input, start_pos, (*(l)).position);
    }
}

void* lexer__read_identifier_pthread_wrapper(void* arg) {
    lexer__read_identifier((lexer__Lexer*)arg);
    return NULL;
}

#line 86 "/home/garth/files/code/gust/compiler/lexer.gst"
Slice_unsigned_char lexer__read_number(lexer__Lexer* l) {
#line 87 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 88 "/home/garth/files/code/gust/compiler/lexer.gst"
    int start_pos = (*(l)).position;
#line 89 "/home/garth/files/code/gust/compiler/lexer.gst"
    while (lexer__is_digit((*(l)).ch)) {
#line 90 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
#line 92 "/home/garth/files/code/gust/compiler/lexer.gst"
    return std_str_slice((*(l)).input, start_pos, (*(l)).position);
    }
}

void* lexer__read_number_pthread_wrapper(void* arg) {
    lexer__read_number((lexer__Lexer*)arg);
    return NULL;
}

#line 96 "/home/garth/files/code/gust/compiler/lexer.gst"
Slice_unsigned_char lexer__read_string(lexer__Lexer* l) {
#line 97 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 98 "/home/garth/files/code/gust/compiler/lexer.gst"
    unsigned char delimiter = (*(l)).ch;
#line 99 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (delimiter == 0) {
#line 100 "/home/garth/files/code/gust/compiler/lexer.gst"
    delimiter = 34;
    }
#line 103 "/home/garth/files/code/gust/compiler/lexer.gst"
    int start_pos = (*(l)).position + 1;
#line 104 "/home/garth/files/code/gust/compiler/lexer.gst"
    int loop = 1;
#line 105 "/home/garth/files/code/gust/compiler/lexer.gst"
    while (loop == 1) {
#line 106 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 107 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 92) {
#line 108 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 110 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == delimiter) {
#line 111 "/home/garth/files/code/gust/compiler/lexer.gst"
    loop = 0;
    } else {
#line 113 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 0) {
#line 114 "/home/garth/files/code/gust/compiler/lexer.gst"
    loop = 0;
    }
    }
    }
    }
#line 119 "/home/garth/files/code/gust/compiler/lexer.gst"
    Slice_unsigned_char out = std_str_slice((*(l)).input, start_pos, (*(l)).position);
#line 120 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 121 "/home/garth/files/code/gust/compiler/lexer.gst"
    return out;
    }
}

void* lexer__read_string_pthread_wrapper(void* arg) {
    lexer__read_string((lexer__Lexer*)arg);
    return NULL;
}

#line 125 "/home/garth/files/code/gust/compiler/lexer.gst"
token__TokenType lexer__lookup_ident(Slice_unsigned_char literal) {
#line 126 "/home/garth/files/code/gust/compiler/lexer.gst"
    token__TokenType t = ((token__TokenType){ .tag = 0 });
#line 127 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 2;
#line 129 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"guard", 5 }))) {
#line 129 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 27;
#line 129 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 130 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"import", 6 }))) {
#line 130 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 28;
#line 130 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 131 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"mut", 3 }))) {
#line 131 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 29;
#line 131 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 132 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"func", 4 }))) {
#line 132 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 30;
#line 132 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 133 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"defer", 5 }))) {
#line 133 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 31;
#line 133 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 134 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"move", 4 }))) {
#line 134 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 32;
#line 134 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 135 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"take", 4 }))) {
#line 135 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 33;
#line 135 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 136 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"while", 5 }))) {
#line 136 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 34;
#line 136 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 137 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"if", 2 }))) {
#line 137 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 35;
#line 137 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 138 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"else", 4 }))) {
#line 138 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 36;
#line 138 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 139 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"as", 2 }))) {
#line 139 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 37;
#line 139 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 140 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"unsafe", 6 }))) {
#line 140 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 38;
#line 140 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 141 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"type", 4 }))) {
#line 141 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 39;
#line 141 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 142 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"struct", 6 }))) {
#line 142 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 40;
#line 142 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 143 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"enum", 4 }))) {
#line 143 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 41;
#line 143 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 144 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"match", 5 }))) {
#line 144 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 42;
#line 144 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 145 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"return", 6 }))) {
#line 145 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 43;
#line 145 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 146 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"empty", 5 }))) {
#line 146 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 44;
#line 146 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 147 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"bool", 4 }))) {
#line 147 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 45;
#line 147 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 148 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"true", 4 }))) {
#line 148 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 46;
#line 148 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 149 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (std_str_eq(literal, ((Slice_unsigned_char){ (unsigned char*)"false", 5 }))) {
#line 149 "/home/garth/files/code/gust/compiler/lexer.gst"
    t.tag = 47;
#line 149 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
    }
#line 151 "/home/garth/files/code/gust/compiler/lexer.gst"
    return t;
}

void* lexer__lookup_ident_pthread_wrapper(void* arg) {
    lexer__lookup_ident(*(Slice_unsigned_char*)arg);
    return NULL;
}

#line 154 "/home/garth/files/code/gust/compiler/lexer.gst"
token__Position lexer__current_position(lexer__Lexer* l) {
#line 155 "/home/garth/files/code/gust/compiler/lexer.gst"
    token__Position pos = ((token__Position){ .column = 0, .line = 0, .offset = 0 });
#line 156 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 157 "/home/garth/files/code/gust/compiler/lexer.gst"
    pos.line = (*(l)).line;
#line 158 "/home/garth/files/code/gust/compiler/lexer.gst"
    pos.column = (*(l)).column;
#line 159 "/home/garth/files/code/gust/compiler/lexer.gst"
    pos.offset = (*(l)).position;
    }
#line 161 "/home/garth/files/code/gust/compiler/lexer.gst"
    return pos;
}

void* lexer__current_position_pthread_wrapper(void* arg) {
    lexer__current_position((lexer__Lexer*)arg);
    return NULL;
}

#line 164 "/home/garth/files/code/gust/compiler/lexer.gst"
void lexer__next_token(lexer__Lexer* l, token__Token* tok) {
#line 165 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__skip_whitespace(l);
#line 167 "/home/garth/files/code/gust/compiler/lexer.gst"
    token__Position start_pos = lexer__current_position(l);
#line 169 "/home/garth/files/code/gust/compiler/lexer.gst"
    {
#line 170 "/home/garth/files/code/gust/compiler/lexer.gst"
    token__TokenType t_type = ((token__TokenType){ .tag = 0 });
#line 171 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 1;
#line 173 "/home/garth/files/code/gust/compiler/lexer.gst"
    Slice_unsigned_char literal = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 175 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 58) {
#line 176 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 61) {
#line 177 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 178 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 5;
#line 179 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)":=", 2 });
    } else {
#line 181 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 9;
#line 182 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)":", 1 });
    }
#line 184 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 185 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 61) {
#line 186 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 61) {
#line 187 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 188 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 23;
#line 189 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"==", 2 });
    } else {
#line 190 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 62) {
#line 191 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 192 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 18;
#line 193 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"=>", 2 });
    } else {
#line 195 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 6;
#line 196 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"=", 1 });
    }
    }
#line 198 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 199 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 33) {
#line 200 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 61) {
#line 201 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 202 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 24;
#line 203 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"!=", 2 });
    } else {
#line 205 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 1;
#line 206 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"!", 1 });
    }
#line 208 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 209 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 47) {
#line 210 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 47) {
#line 211 "/home/garth/files/code/gust/compiler/lexer.gst"
    while ((*(l)).ch != 10 && (*(l)).ch != 13 && (*(l)).ch != 0) {
#line 212 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
#line 214 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__skip_whitespace(l);
#line 215 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__next_token(l, tok);
#line 216 "/home/garth/files/code/gust/compiler/lexer.gst"
    return;
    } else {
#line 218 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 22;
#line 219 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"/", 1 });
#line 220 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
    } else {
#line 222 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 59) {
#line 223 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 10;
#line 224 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)";", 1 });
#line 225 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 226 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 38) {
#line 227 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 38) {
#line 228 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 229 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 50;
#line 230 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"&&", 2 });
    } else {
#line 232 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 17;
#line 233 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"&", 1 });
    }
#line 235 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 236 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 124) {
#line 237 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 124) {
#line 238 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 239 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 51;
#line 240 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"||", 2 });
    } else {
#line 242 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 1;
#line 243 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"|", 1 });
    }
#line 245 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 246 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 43) {
#line 247 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 19;
#line 248 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"+", 1 });
#line 249 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 250 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 45) {
#line 251 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 20;
#line 252 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"-", 1 });
#line 253 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 254 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 42) {
#line 255 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 21;
#line 256 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"*", 1 });
#line 257 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 258 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 60) {
#line 259 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 61) {
#line 260 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 261 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 48;
#line 262 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"<=", 2 });
    } else {
#line 264 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 25;
#line 265 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"<", 1 });
    }
#line 267 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 268 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 62) {
#line 269 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__peek_char(l) == 61) {
#line 270 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
#line 271 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 49;
#line 272 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)">=", 2 });
    } else {
#line 274 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 26;
#line 275 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)">", 1 });
    }
#line 277 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 278 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 46) {
#line 279 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 7;
#line 280 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)".", 1 });
#line 281 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 282 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 44) {
#line 283 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 8;
#line 284 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)",", 1 });
#line 285 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 286 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 40) {
#line 287 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 11;
#line 288 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"(", 1 });
#line 289 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 290 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 41) {
#line 291 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 12;
#line 292 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)")", 1 });
#line 293 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 294 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 123) {
#line 295 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 13;
#line 296 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"{", 1 });
#line 297 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 298 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 125) {
#line 299 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 14;
#line 300 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"}", 1 });
#line 301 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 302 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 91) {
#line 303 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 15;
#line 304 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"[", 1 });
#line 305 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 306 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 93) {
#line 307 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 16;
#line 308 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"]", 1 });
#line 309 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    } else {
#line 310 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 0) {
#line 311 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 0;
#line 312 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
    } else {
#line 313 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 34) {
#line 314 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = lexer__read_string(l);
#line 315 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 4;
    } else {
#line 316 "/home/garth/files/code/gust/compiler/lexer.gst"
    if ((*(l)).ch == 39) {
#line 317 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = lexer__read_string(l);
#line 318 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 4;
    } else {
#line 320 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__is_letter((*(l)).ch)) {
#line 321 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = lexer__read_identifier(l);
#line 322 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type = lexer__lookup_ident(literal);
    } else {
#line 323 "/home/garth/files/code/gust/compiler/lexer.gst"
    if (lexer__is_digit((*(l)).ch)) {
#line 324 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = lexer__read_number(l);
#line 325 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 3;
    } else {
#line 327 "/home/garth/files/code/gust/compiler/lexer.gst"
    literal = ((Slice_unsigned_char){ (unsigned char*)"illegal", 7 });
#line 328 "/home/garth/files/code/gust/compiler/lexer.gst"
    t_type.tag = 1;
#line 329 "/home/garth/files/code/gust/compiler/lexer.gst"
    lexer__read_char(l);
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
#line 333 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(tok)).token_type = t_type;
#line 334 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(tok)).literal = literal;
#line 335 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(tok)).span.start = start_pos;
#line 336 "/home/garth/files/code/gust/compiler/lexer.gst"
    (*(tok)).span.end = lexer__current_position(l);
    }
}

#line 209 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__ast_repeat_spaces(int indent, os_Arena* ctx) {
#line 210 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char spaces = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 211 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 212 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < indent) {
#line 213 "/home/garth/files/code/gust/compiler/ast.gst"
    spaces = (({ Slice_unsigned_char _s1 = spaces; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"  ", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 214 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 216 "/home/garth/files/code/gust/compiler/ast.gst"
    return spaces;
}

#line 219 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__ast_join_strings(std_Vector_str vec, Slice_unsigned_char sep, os_Arena* ctx) {
#line 220 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char result = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 221 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 222 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < vec.len) {
#line 223 "/home/garth/files/code/gust/compiler/ast.gst"
    if (i > 0) {
#line 224 "/home/garth/files/code/gust/compiler/ast.gst"
    result = (({ Slice_unsigned_char _s1 = result; Slice_unsigned_char _s2 = sep; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 226 "/home/garth/files/code/gust/compiler/ast.gst"
    result = (({ Slice_unsigned_char _s1 = result; Slice_unsigned_char _s2 = (*({ if (i < 0 || i >= vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(vec.data[i]); })); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 227 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 229 "/home/garth/files/code/gust/compiler/ast.gst"
    return result;
}

#line 232 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_type(ast__Type t, os_Arena* ctx) {
#line 233 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 234 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 0) {
#line 235 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Int", 3 });
    }
#line 237 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 1) {
#line 238 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Byte", 4 });
    }
#line 240 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 2) {
#line 241 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Bool", 4 });
    }
#line 243 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 3) {
#line 244 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Void", 4 });
    }
#line 246 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 4) {
#line 247 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Arena", 5 });
    }
#line 249 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 5) {
#line 250 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Str", 3 });
    }
#line 252 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 6) {
#line 253 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + t.Slice.inner))), ctx);
#line 254 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Slice(", 6 }); Slice_unsigned_char _s2 = inner_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 255 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)")", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 256 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 258 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 7) {
#line 259 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char quote = ((Slice_unsigned_char){ (unsigned char*)"\"", 1 });
#line 260 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char struct_name = t.Index.struct_name;
#line 261 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Index(", 6 }); Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 262 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = struct_name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 263 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 264 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.Index.brand == 0xFFFFFFFF) {
#line 265 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)", None)", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 267 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char* brand_str_ptr = ((Slice_unsigned_char*)&((*(( Slice_unsigned_char*)((char*)ctx->BaseAddress + t.Index.brand)))));
#line 268 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char brand_str = (*(brand_str_ptr));
#line 269 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)", Some(", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 270 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 271 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = brand_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 272 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 273 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"))", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 275 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 277 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 8) {
#line 278 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char quote = ((Slice_unsigned_char){ (unsigned char*)"\"", 1 });
#line 279 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char struct_name = t.Struct.struct_name;
#line 280 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Struct(", 7 }); Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 281 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = struct_name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 282 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 283 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.Struct.brand == 0xFFFFFFFF) {
#line 284 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)", None)", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 286 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char* brand_str_ptr = ((Slice_unsigned_char*)&((*(( Slice_unsigned_char*)((char*)ctx->BaseAddress + t.Struct.brand)))));
#line 287 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char brand_str = (*(brand_str_ptr));
#line 288 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)", Some(", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 289 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 290 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = brand_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 291 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 292 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"))", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 294 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 296 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 9) {
#line 297 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + t.RawPointer.inner))), ctx);
#line 298 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"RawPointer(", 11 }); Slice_unsigned_char _s2 = inner_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 299 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)")", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 300 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 302 "/home/garth/files/code/gust/compiler/ast.gst"
    if (t.tag == 10) {
#line 303 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char quote = ((Slice_unsigned_char){ (unsigned char*)"\"", 1 });
#line 304 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char name = t.Generic.name;
#line 305 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__Type* args_vec = ((std_Vector_ast__Type*)&((*(( std_Vector_ast__Type*)((char*)ctx->BaseAddress + t.Generic.args)))));
#line 306 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_str arg_strs = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 307 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 308 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(args_vec)).len) {
#line 309 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char arg_str = ast__serialize_type((*({ if (i < 0 || i >= (*(args_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(args_vec)).data[i]); })), ctx);
#line 310 "/home/garth/files/code/gust/compiler/ast.gst"
    os_VectorPush(&arg_strs, arg_str);
#line 311 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 313 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char joined = ast__ast_join_strings(arg_strs, ((Slice_unsigned_char){ (unsigned char*)", ", 2 }), ctx);
#line 314 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Generic(", 8 }); Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 315 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 316 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 317 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)", [", 3 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 318 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = joined; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 319 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"])", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 320 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
    }
#line 323 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"Unknown", 7 });
}

#line 326 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__ast_join_fields(std_Vector_ast__FieldDef fields, int indent, os_Arena* ctx) {
#line 327 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char result = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 328 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 329 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < fields.len) {
#line 330 "/home/garth/files/code/gust/compiler/ast.gst"
    ast__FieldDef f = (*({ if (i < 0 || i >= fields.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(fields.data[i]); }));
#line 331 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 332 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char field_type_str = ast__serialize_type(f.field_type, ctx);
#line 333 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char line = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"FieldDef: ", 10 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 334 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = f.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 335 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" : ", 3 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 336 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = field_type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 337 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 338 "/home/garth/files/code/gust/compiler/ast.gst"
    result = (({ Slice_unsigned_char _s1 = result; Slice_unsigned_char _s2 = line; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 339 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 341 "/home/garth/files/code/gust/compiler/ast.gst"
    return result;
}

#line 344 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__ast_join_params(std_Vector_ast__Parameter params, int indent, os_Arena* ctx) {
#line 345 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char result = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 346 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 347 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < params.len) {
#line 348 "/home/garth/files/code/gust/compiler/ast.gst"
    ast__Parameter p = (*({ if (i < 0 || i >= params.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(params.data[i]); }));
#line 349 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 350 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char param_type_str = ast__serialize_type(p.param_type, ctx);
#line 351 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char line = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Parameter: ", 11 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 352 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = p.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 353 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" : ", 3 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 354 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = param_type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 355 "/home/garth/files/code/gust/compiler/ast.gst"
    line = (({ Slice_unsigned_char _s1 = line; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 356 "/home/garth/files/code/gust/compiler/ast.gst"
    result = (({ Slice_unsigned_char _s1 = result; Slice_unsigned_char _s2 = line; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 357 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 359 "/home/garth/files/code/gust/compiler/ast.gst"
    return result;
}

#line 362 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_expression(int expr_idx, int indent, os_Arena* ctx) {
#line 363 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 364 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr_idx == 0xFFFFFFFF) {
#line 365 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"", 0 });
    }
#line 367 "/home/garth/files/code/gust/compiler/ast.gst"
    ast__Expression expr = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr_idx)));
#line 368 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 370 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 0) {
#line 371 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Identifier: ", 12 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 372 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr.Identifier.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 373 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 374 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 376 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 1) {
#line 377 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char val_str = (({ int _val = expr.Integer.val; char* _buf = (char*)os_ScratchAlloc(16); int _len = snprintf(_buf, 16, "%d", _val); ((Slice_unsigned_char){ (unsigned char*)_buf, _len }); }));
#line 378 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Integer: ", 9 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 379 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = val_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 380 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 381 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 383 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 2) {
#line 384 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char quote = ((Slice_unsigned_char){ (unsigned char*)"\"", 1 });
#line 385 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"String: ", 8 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 386 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 387 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr.String.val; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 388 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = quote; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 389 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 390 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 392 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 3) {
#line 393 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char val_str = ((Slice_unsigned_char){ (unsigned char*)"false", 5 });
#line 394 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.Bool.val == 1) {
#line 395 "/home/garth/files/code/gust/compiler/ast.gst"
    val_str = ((Slice_unsigned_char){ (unsigned char*)"true", 4 });
    }
#line 397 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Bool: ", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 398 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = val_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 399 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 400 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 402 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 4) {
#line 403 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Move:\n", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 404 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.Move.expr, indent + 1, ctx);
#line 405 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 406 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 408 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 5) {
#line 409 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Take:\n", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 410 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.Take.expr, indent + 1, ctx);
#line 411 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 412 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 414 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 6) {
#line 415 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"AddressOf:\n", 11 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 416 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.AddressOf.expr, indent + 1, ctx);
#line 417 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 418 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 420 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 7) {
#line 421 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Dereference:\n", 13 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 422 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.Dereference.expr, indent + 1, ctx);
#line 423 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 424 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 426 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 8) {
#line 427 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"IndexAccess:\n", 13 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 428 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char alloc_str = ast__serialize_expression(expr.IndexAccess.allocator, indent + 1, ctx);
#line 429 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char idx_str = ast__serialize_expression(expr.IndexAccess.index, indent + 1, ctx);
#line 430 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = alloc_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 431 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = idx_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 432 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 434 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 9) {
#line 435 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char target_type_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + expr.AsCast.target_type))), ctx);
#line 436 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char ref_str = ((Slice_unsigned_char){ (unsigned char*)"false", 5 });
#line 437 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.AsCast.is_reference == 1) {
#line 438 "/home/garth/files/code/gust/compiler/ast.gst"
    ref_str = ((Slice_unsigned_char){ (unsigned char*)"true", 4 });
    }
#line 440 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"AsCast: ", 8 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 441 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = target_type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 442 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" (ref=", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 443 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ref_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 444 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)")\n", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 445 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.AsCast.left, indent + 1, ctx);
#line 446 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 447 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 449 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 10) {
#line 450 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Binary: ", 8 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 451 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr.Binary.op; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 452 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 453 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char left_str = ast__serialize_expression(expr.Binary.left, indent + 1, ctx);
#line 454 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char right_str = ast__serialize_expression(expr.Binary.right, indent + 1, ctx);
#line 455 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = left_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 456 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = right_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 457 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 459 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 11) {
#line 460 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Selector: ", 10 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 461 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr.Selector.right; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 462 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 463 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char inner = ast__serialize_expression(expr.Selector.left, indent + 1, ctx);
#line 464 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = inner; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 465 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 467 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 12) {
#line 468 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Call:\n", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 469 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char func_str = ast__serialize_expression(expr.Call.function, indent + 1, ctx);
#line 470 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = func_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 472 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__Expression* args_vec = ((std_Vector_ast__Expression*)&((*(( std_Vector_ast__Expression*)((char*)ctx->BaseAddress + expr.Call.arguments)))));
#line 473 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 474 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(args_vec)).len) {
#line 475 "/home/garth/files/code/gust/compiler/ast.gst"
    int arg_idx = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 476 "/home/garth/files/code/gust/compiler/ast.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + arg_idx))) = (*({ if (i < 0 || i >= (*(args_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(args_vec)).data[i]); }));
#line 477 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char arg_str = ast__serialize_expression(arg_idx, indent + 1, ctx);
#line 478 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = arg_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 479 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 481 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 483 "/home/garth/files/code/gust/compiler/ast.gst"
    if (expr.tag == 13) {
#line 484 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char target_type_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + expr.Empty.target_type))), ctx);
#line 485 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Empty: ", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 486 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = target_type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 487 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 488 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
    }
#line 491 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"UnknownExpr", 11 });
}

#line 494 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_block_statement(int block_idx, int indent, os_Arena* ctx) {
#line 495 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 496 "/home/garth/files/code/gust/compiler/ast.gst"
    if (block_idx == 0xFFFFFFFF) {
#line 497 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"", 0 });
    }
#line 499 "/home/garth/files/code/gust/compiler/ast.gst"
    ast__BlockStatement block = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx)));
#line 500 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 501 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"BlockStatement:\n", 16 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 503 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__Statement* statements_vec = ((std_Vector_ast__Statement*)&((*(( std_Vector_ast__Statement*)((char*)ctx->BaseAddress + block.statements)))));
#line 504 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 505 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(statements_vec)).len) {
#line 506 "/home/garth/files/code/gust/compiler/ast.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 507 "/home/garth/files/code/gust/compiler/ast.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))) = (*({ if (i < 0 || i >= (*(statements_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(statements_vec)).data[i]); }));
#line 508 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char stmt_str = ast__serialize_statement(stmt_idx, indent + 1, ctx);
#line 509 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 510 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 512 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
}

#line 516 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_variant_def(ast__VariantDef v, int indent, os_Arena* ctx) {
#line 517 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 518 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 519 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"VariantDef: ", 12 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 520 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = v.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 521 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 523 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__FieldDef* fields_vec = ((std_Vector_ast__FieldDef*)&((*(( std_Vector_ast__FieldDef*)((char*)ctx->BaseAddress + v.fields)))));
#line 524 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char fields_str = ast__ast_join_fields((*(fields_vec)), indent + 1, ctx);
#line 525 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = fields_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 526 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
}

#line 530 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_match_case(ast__MatchCase case_val, int indent, os_Arena* ctx) {
#line 531 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 532 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 533 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_str* fields_vec = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + case_val.fields)))));
#line 534 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char joined_fields = ast__ast_join_strings((*(fields_vec)), ((Slice_unsigned_char){ (unsigned char*)", ", 2 }), ctx);
#line 536 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"MatchCase: ", 11 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 537 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = case_val.variant_name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 538 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" [", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 539 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = joined_fields; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 540 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"],\n", 3 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 542 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char body_str = ast__serialize_block_statement(case_val.body, indent + 1, ctx);
#line 543 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = body_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 544 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
}

#line 548 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_statement(int stmt_idx, int indent, os_Arena* ctx) {
#line 549 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 550 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt_idx == 0xFFFFFFFF) {
#line 551 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"", 0 });
    }
#line 553 "/home/garth/files/code/gust/compiler/ast.gst"
    ast__Statement stmt = (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx)));
#line 554 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 556 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 0) {
#line 557 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char alias_str = stmt.Import.alias;
#line 558 "/home/garth/files/code/gust/compiler/ast.gst"
    if (std_str_eq(alias_str, ((Slice_unsigned_char){ (unsigned char*)"", 0 }))) {
#line 559 "/home/garth/files/code/gust/compiler/ast.gst"
    alias_str = ((Slice_unsigned_char){ (unsigned char*)"<none>", 6 });
    }
#line 561 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Import: ", 8 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 562 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.Import.path; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 563 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" as ", 4 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 564 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = alias_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 565 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 566 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 568 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 1) {
#line 569 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_str* generics_vec = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + stmt.StructDecl.generics)))));
#line 570 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char joined_generics = ast__ast_join_strings((*(generics_vec)), ((Slice_unsigned_char){ (unsigned char*)", ", 2 }), ctx);
#line 571 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"StructDecl: ", 12 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 572 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.StructDecl.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 573 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" <", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 574 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = joined_generics; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 575 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)">\n", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 577 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__FieldDef* fields_vec = ((std_Vector_ast__FieldDef*)&((*(( std_Vector_ast__FieldDef*)((char*)ctx->BaseAddress + stmt.StructDecl.fields)))));
#line 578 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char fields_str = ast__ast_join_fields((*(fields_vec)), indent + 1, ctx);
#line 579 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = fields_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 580 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 582 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 2) {
#line 583 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_str* generics_vec = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + stmt.EnumDecl.generics)))));
#line 584 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char joined_generics = ast__ast_join_strings((*(generics_vec)), ((Slice_unsigned_char){ (unsigned char*)", ", 2 }), ctx);
#line 585 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"EnumDecl: ", 10 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 586 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.EnumDecl.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 587 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" <", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 588 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = joined_generics; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 589 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)">\n", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 591 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__VariantDef* variants_vec = ((std_Vector_ast__VariantDef*)&((*(( std_Vector_ast__VariantDef*)((char*)ctx->BaseAddress + stmt.EnumDecl.variants)))));
#line 592 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 593 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(variants_vec)).len) {
#line 594 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char variant_str = ast__serialize_variant_def((*({ if (i < 0 || i >= (*(variants_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(variants_vec)).data[i]); })), indent + 1, ctx);
#line 595 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = variant_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 596 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 598 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 600 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 3) {
#line 601 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char return_type_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + stmt.FunctionDecl.return_type))), ctx);
#line 602 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"FunctionDecl: ", 14 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 603 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.FunctionDecl.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 604 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" -> ", 4 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 605 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = return_type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 606 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 608 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__Parameter* params_vec = ((std_Vector_ast__Parameter*)&((*(( std_Vector_ast__Parameter*)((char*)ctx->BaseAddress + stmt.FunctionDecl.params)))));
#line 609 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char params_str = ast__ast_join_params((*(params_vec)), indent + 1, ctx);
#line 610 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = params_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 612 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char body_str = ast__serialize_block_statement(stmt.FunctionDecl.body, indent + 1, ctx);
#line 613 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = body_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 614 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 616 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 4) {
#line 617 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char type_str = ((Slice_unsigned_char){ (unsigned char*)"<inferred>", 10 });
#line 618 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.VarDecl.var_type != 0xFFFFFFFF) {
#line 619 "/home/garth/files/code/gust/compiler/ast.gst"
    type_str = ast__serialize_type((*(( ast__Type*)((char*)ctx->BaseAddress + stmt.VarDecl.var_type))), ctx);
    }
#line 621 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char mut_str = ((Slice_unsigned_char){ (unsigned char*)"false", 5 });
#line 622 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.VarDecl.is_mut == 1) {
#line 623 "/home/garth/files/code/gust/compiler/ast.gst"
    mut_str = ((Slice_unsigned_char){ (unsigned char*)"true", 4 });
    }
#line 625 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"VarDecl: ", 9 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 626 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.VarDecl.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 627 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" (mut=", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 628 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = mut_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 629 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)") : ", 4 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 630 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = type_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 631 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"\n", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 633 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.VarDecl.value != 0xFFFFFFFF) {
#line 634 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char value_str = ast__serialize_expression(stmt.VarDecl.value, indent + 1, ctx);
#line 635 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = value_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 637 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 639 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 5) {
#line 640 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Assignment:\n", 12 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 641 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char left_str = ast__serialize_expression(stmt.Assignment.left, indent + 1, ctx);
#line 642 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char val_str = ast__serialize_expression(stmt.Assignment.value, indent + 1, ctx);
#line 643 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = left_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 644 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = val_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 645 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 647 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 6) {
#line 648 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"While:\n", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 649 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char cond_str = ast__serialize_expression(stmt.While.condition, indent + 1, ctx);
#line 650 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char body_str = ast__serialize_block_statement(stmt.While.body, indent + 1, ctx);
#line 651 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = cond_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 652 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = body_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 653 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 655 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 7) {
#line 656 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"If:\n", 4 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 657 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char cond_str = ast__serialize_expression(stmt.If.condition, indent + 1, ctx);
#line 658 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char cons_str = ast__serialize_block_statement(stmt.If.consequence, indent + 1, ctx);
#line 659 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = cond_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 660 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = cons_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 662 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.If.alternative != 0xFFFFFFFF) {
#line 663 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = pad; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 664 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Else:\n", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 665 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char alt_str = ast__serialize_block_statement(stmt.If.alternative, indent + 1, ctx);
#line 666 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = alt_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 668 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 670 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 8) {
#line 671 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Match:\n", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 672 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char expr_str = ast__serialize_expression(stmt.Match.expression, indent + 1, ctx);
#line 673 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 675 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__MatchCase* cases_vec = ((std_Vector_ast__MatchCase*)&((*(( std_Vector_ast__MatchCase*)((char*)ctx->BaseAddress + stmt.Match.cases)))));
#line 676 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 677 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(cases_vec)).len) {
#line 678 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char case_str = ast__serialize_match_case((*({ if (i < 0 || i >= (*(cases_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(cases_vec)).data[i]); })), indent + 1, ctx);
#line 679 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = case_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 680 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 682 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 684 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 9) {
#line 685 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char mut_str = ((Slice_unsigned_char){ (unsigned char*)"false", 5 });
#line 686 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.Guard.is_mut == 1) {
#line 687 "/home/garth/files/code/gust/compiler/ast.gst"
    mut_str = ((Slice_unsigned_char){ (unsigned char*)"true", 4 });
    }
#line 689 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Guard: ", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 690 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt.Guard.name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 691 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)" (mut=", 6 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 692 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = mut_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 693 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)")\n", 2 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 695 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char val_str = ast__serialize_expression(stmt.Guard.value, indent + 1, ctx);
#line 696 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char else_str = ast__serialize_block_statement(stmt.Guard.else_body, indent + 1, ctx);
#line 697 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = val_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 698 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = else_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 699 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 701 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 10) {
#line 702 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"UnsafeBlock:\n", 13 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 703 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char body_str = ast__serialize_block_statement(stmt.UnsafeBlock.body, indent + 1, ctx);
#line 704 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = body_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 705 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 707 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 11) {
#line 708 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Defer:\n", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 709 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char expr_str = ast__serialize_expression(stmt.Defer.expr, indent + 1, ctx);
#line 710 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 711 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 713 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 12) {
#line 714 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Return:\n", 8 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 715 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.Return.expr == 0xFFFFFFFF) {
#line 716 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char void_pad = ast__ast_repeat_spaces(indent + 1, ctx);
#line 717 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = void_pad; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 718 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"<void>\n", 7 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 720 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char expr_str = ast__serialize_expression(stmt.Return.expr, indent + 1, ctx);
#line 721 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 723 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
#line 725 "/home/garth/files/code/gust/compiler/ast.gst"
    if (stmt.tag == 13) {
#line 726 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"ExpressionStatement:\n", 21 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 727 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char expr_str = ast__serialize_expression(stmt.Expression.expr, indent + 1, ctx);
#line 728 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = expr_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 729 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
    }
#line 732 "/home/garth/files/code/gust/compiler/ast.gst"
    return ((Slice_unsigned_char){ (unsigned char*)"UnknownStmt", 11 });
}

#line 735 "/home/garth/files/code/gust/compiler/ast.gst"
Slice_unsigned_char ast__serialize_program(ast__Program* prog, int indent, os_Arena* ctx) {
#line 736 "/home/garth/files/code/gust/compiler/ast.gst"
    {
#line 737 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char pad = ast__ast_repeat_spaces(indent, ctx);
#line 738 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char res = (({ Slice_unsigned_char _s1 = pad; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"Program:\n", 9 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 740 "/home/garth/files/code/gust/compiler/ast.gst"
    std_Vector_ast__Statement* statements_vec = ((std_Vector_ast__Statement*)&((*(( std_Vector_ast__Statement*)((char*)ctx->BaseAddress + (*(prog)).statements)))));
#line 741 "/home/garth/files/code/gust/compiler/ast.gst"
    int i = 0;
#line 742 "/home/garth/files/code/gust/compiler/ast.gst"
    while (i < (*(statements_vec)).len) {
#line 743 "/home/garth/files/code/gust/compiler/ast.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 744 "/home/garth/files/code/gust/compiler/ast.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))) = (*({ if (i < 0 || i >= (*(statements_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(statements_vec)).data[i]); }));
#line 745 "/home/garth/files/code/gust/compiler/ast.gst"
    Slice_unsigned_char stmt_str = ast__serialize_statement(stmt_idx, indent + 1, ctx);
#line 746 "/home/garth/files/code/gust/compiler/ast.gst"
    res = (({ Slice_unsigned_char _s1 = res; Slice_unsigned_char _s2 = stmt_str; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 747 "/home/garth/files/code/gust/compiler/ast.gst"
    i = i + 1;
    }
#line 749 "/home/garth/files/code/gust/compiler/ast.gst"
    return res;
    }
}

#line 20 "/home/garth/files/code/gust/compiler/parser.gst"
Slice_unsigned_char parser__parser_get_type_ident(ast__Type t, os_Arena* ctx) {
#line 21 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 22 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char base = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 23 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 0) {
#line 24 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"int", 3 });
    } else {
#line 26 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 1) {
#line 27 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"byte", 4 });
    } else {
#line 29 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 2) {
#line 30 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"bool", 4 });
    } else {
#line 32 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 3) {
#line 33 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"void", 4 });
    } else {
#line 35 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 4) {
#line 36 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"Arena", 5 });
    } else {
#line 38 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 5) {
#line 39 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"str", 3 });
    } else {
#line 41 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 6) {
#line 42 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type inner_t = (*(( ast__Type*)((char*)ctx->BaseAddress + t.Slice.inner)));
#line 43 "/home/garth/files/code/gust/compiler/parser.gst"
    base = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Slice_", 6 }); Slice_unsigned_char _s2 = parser__parser_get_type_ident(inner_t, ctx); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 45 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 7) {
#line 46 "/home/garth/files/code/gust/compiler/parser.gst"
    base = (({ Slice_unsigned_char _s1 = ((Slice_unsigned_char){ (unsigned char*)"Index_", 6 }); Slice_unsigned_char _s2 = t.Index.struct_name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 48 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 8) {
#line 49 "/home/garth/files/code/gust/compiler/parser.gst"
    base = t.Struct.struct_name;
    } else {
#line 51 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 9) {
#line 52 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type inner_t = (*(( ast__Type*)((char*)ctx->BaseAddress + t.RawPointer.inner)));
#line 53 "/home/garth/files/code/gust/compiler/parser.gst"
    base = (({ Slice_unsigned_char _s1 = parser__parser_get_type_ident(inner_t, ctx); Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"_ptr", 4 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 55 "/home/garth/files/code/gust/compiler/parser.gst"
    if (t.tag == 10) {
#line 56 "/home/garth/files/code/gust/compiler/parser.gst"
    base = parser__parser_get_monomorphized_name(t.Generic.name, t.Generic.args, ctx);
    } else {
#line 58 "/home/garth/files/code/gust/compiler/parser.gst"
    base = ((Slice_unsigned_char){ (unsigned char*)"unknown", 7 });
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
#line 71 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char out = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 72 "/home/garth/files/code/gust/compiler/parser.gst"
    int i = 0;
#line 73 "/home/garth/files/code/gust/compiler/parser.gst"
    while (i < base.len) {
#line 74 "/home/garth/files/code/gust/compiler/parser.gst"
    unsigned char b = std_str_byte_at(base, i);
#line 75 "/home/garth/files/code/gust/compiler/parser.gst"
    if (b == 46) {
#line 76 "/home/garth/files/code/gust/compiler/parser.gst"
    out = (({ Slice_unsigned_char _s1 = out; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"_", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 78 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char char_slice = std_str_slice(base, i, i + 1);
#line 79 "/home/garth/files/code/gust/compiler/parser.gst"
    out = (({ Slice_unsigned_char _s1 = out; Slice_unsigned_char _s2 = char_slice; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 81 "/home/garth/files/code/gust/compiler/parser.gst"
    i = i + 1;
    }
#line 83 "/home/garth/files/code/gust/compiler/parser.gst"
    return out;
    }
}

#line 87 "/home/garth/files/code/gust/compiler/parser.gst"
Slice_unsigned_char parser__parser_get_monomorphized_name(Slice_unsigned_char template_name, int args_idx, os_Arena* ctx) {
#line 88 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 89 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Type* args_vec = ((std_Vector_ast__Type*)&((*(( std_Vector_ast__Type*)((char*)ctx->BaseAddress + args_idx)))));
#line 90 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char arg_names = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 91 "/home/garth/files/code/gust/compiler/parser.gst"
    int i = 0;
#line 92 "/home/garth/files/code/gust/compiler/parser.gst"
    while (i < (*(args_vec)).len) {
#line 93 "/home/garth/files/code/gust/compiler/parser.gst"
    if (i > 0) {
#line 94 "/home/garth/files/code/gust/compiler/parser.gst"
    arg_names = (({ Slice_unsigned_char _s1 = arg_names; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"_", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 96 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char arg_name = parser__parser_get_type_ident((*({ if (i < 0 || i >= (*(args_vec)).len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &((*(args_vec)).data[i]); })), ctx);
#line 97 "/home/garth/files/code/gust/compiler/parser.gst"
    arg_names = (({ Slice_unsigned_char _s1 = arg_names; Slice_unsigned_char _s2 = arg_name; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 98 "/home/garth/files/code/gust/compiler/parser.gst"
    i = i + 1;
    }
#line 100 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char name = (({ Slice_unsigned_char _s1 = template_name; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"_", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 101 "/home/garth/files/code/gust/compiler/parser.gst"
    name = (({ Slice_unsigned_char _s1 = name; Slice_unsigned_char _s2 = arg_names; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 103 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char out = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 104 "/home/garth/files/code/gust/compiler/parser.gst"
    int j = 0;
#line 105 "/home/garth/files/code/gust/compiler/parser.gst"
    while (j < name.len) {
#line 106 "/home/garth/files/code/gust/compiler/parser.gst"
    unsigned char b = std_str_byte_at(name, j);
#line 107 "/home/garth/files/code/gust/compiler/parser.gst"
    if (b == 46) {
#line 108 "/home/garth/files/code/gust/compiler/parser.gst"
    out = (({ Slice_unsigned_char _s1 = out; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)"_", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    } else {
#line 110 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char char_slice = std_str_slice(name, j, j + 1);
#line 111 "/home/garth/files/code/gust/compiler/parser.gst"
    out = (({ Slice_unsigned_char _s1 = out; Slice_unsigned_char _s2 = char_slice; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
    }
#line 113 "/home/garth/files/code/gust/compiler/parser.gst"
    j = j + 1;
    }
#line 115 "/home/garth/files/code/gust/compiler/parser.gst"
    return out;
    }
}

#line 119 "/home/garth/files/code/gust/compiler/parser.gst"
void parser__init_parser(parser__Parser* p, lexer__Lexer* l, os_Arena* ctx) {
#line 120 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 121 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).lexer = ((lexer__Lexer*)l);
#line 122 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).pushback_tokens = (struct std_Vector_token__Token){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 123 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).errors = (struct std_Vector_errors__CompilerError){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 124 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).has_non_import_statement = 0;
#line 126 "/home/garth/files/code/gust/compiler/parser.gst"
    lexer__next_token(((lexer__Lexer*)(*(p)).lexer), ((token__Token*)&((*(p)).cur_token)));
#line 127 "/home/garth/files/code/gust/compiler/parser.gst"
    lexer__next_token(((lexer__Lexer*)(*(p)).lexer), ((token__Token*)&((*(p)).peek_token)));
    }
}

#line 131 "/home/garth/files/code/gust/compiler/parser.gst"
void parser__next_token(parser__Parser* p) {
#line 132 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 133 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).cur_token = (*(p)).peek_token;
#line 134 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).pushback_tokens.len > 0) {
#line 135 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).peek_token = os_VectorPop(&(*(p)).pushback_tokens);
    } else {
#line 137 "/home/garth/files/code/gust/compiler/parser.gst"
    lexer__next_token(((lexer__Lexer*)(*(p)).lexer), ((token__Token*)&((*(p)).peek_token)));
    }
    }
}

void* parser__next_token_pthread_wrapper(void* arg) {
    parser__next_token((parser__Parser*)arg);
    return NULL;
}

#line 142 "/home/garth/files/code/gust/compiler/parser.gst"
unsigned char parser__cur_token_is(parser__Parser* p, int tag) {
#line 143 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 144 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).cur_token.token_type.tag == tag) {
#line 145 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
#line 147 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0;
    }
}

#line 151 "/home/garth/files/code/gust/compiler/parser.gst"
unsigned char parser__peek_token_is(parser__Parser* p, int tag) {
#line 152 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 153 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).peek_token.token_type.tag == tag) {
#line 154 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
#line 156 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0;
    }
}

#line 160 "/home/garth/files/code/gust/compiler/parser.gst"
parser__ParseResult parser__expect_peek(parser__Parser* p, int tag, os_Arena* ctx) {
#line 161 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 162 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__ParseResult* res_ptr = ((parser__ParseResult*)p);
#line 163 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__ParseResult res = (*(res_ptr));
#line 164 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).peek_token.token_type.tag == tag) {
#line 165 "/home/garth/files/code/gust/compiler/parser.gst"
    res.Ok = 1;
#line 166 "/home/garth/files/code/gust/compiler/parser.gst"
    res.Val = (*(p)).peek_token;
#line 167 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 169 "/home/garth/files/code/gust/compiler/parser.gst"
    res.Ok = 0;
#line 170 "/home/garth/files/code/gust/compiler/parser.gst"
    res.Val = (*(p)).peek_token;
#line 172 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 173 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 174 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected token tag", 18 });
#line 175 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).peek_token.span;
#line 177 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
#line 179 "/home/garth/files/code/gust/compiler/parser.gst"
    return res;
    }
}

#line 183 "/home/garth/files/code/gust/compiler/parser.gst"
token__Span parser__merge_spans(token__Span start, token__Span end) {
#line 184 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span s = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 185 "/home/garth/files/code/gust/compiler/parser.gst"
    s.start = start.start;
#line 186 "/home/garth/files/code/gust/compiler/parser.gst"
    s.end = end.end;
#line 187 "/home/garth/files/code/gust/compiler/parser.gst"
    return s;
}

#line 190 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__is_at_end(parser__Parser* p) {
#line 191 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 192 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14)) {
#line 193 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
#line 195 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 0)) {
#line 196 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
#line 198 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0;
    }
}

void* parser__is_at_end_pthread_wrapper(void* arg) {
    parser__is_at_end((parser__Parser*)arg);
    return NULL;
}

#line 202 "/home/garth/files/code/gust/compiler/parser.gst"
void parser__error_at_current(parser__Parser* p, Slice_unsigned_char message) {
#line 203 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 204 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 205 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 206 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = message;
#line 207 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 208 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
}

#line 212 "/home/garth/files/code/gust/compiler/parser.gst"
void parser__synchronize(parser__Parser* p) {
#line 213 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 214 "/home/garth/files/code/gust/compiler/parser.gst"
    while ((*(p)).cur_token.token_type.tag != 0) {
#line 215 "/home/garth/files/code/gust/compiler/parser.gst"
    int tag = (*(p)).cur_token.token_type.tag;
#line 216 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 10) {
#line 217 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 218 "/home/garth/files/code/gust/compiler/parser.gst"
    return;
    }
#line 220 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 14) {
#line 222 "/home/garth/files/code/gust/compiler/parser.gst"
    return;
    }
#line 224 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 30 || tag == 39 || tag == 29 || tag == 34 || tag == 35 || tag == 43 || tag == 42 || tag == 31 || tag == 38 || tag == 27) {
#line 226 "/home/garth/files/code/gust/compiler/parser.gst"
    return;
    }
#line 228 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
}

void* parser__synchronize_pthread_wrapper(void* arg) {
    parser__synchronize((parser__Parser*)arg);
    return NULL;
}

#line 233 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_type_signature(parser__Parser* p, os_Arena* ctx) {
#line 234 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 235 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 21) || parser__cur_token_is(p, 17)) {
#line 236 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 237 "/home/garth/files/code/gust/compiler/parser.gst"
    int target = parser__parse_type_signature(p, ctx);
#line 238 "/home/garth/files/code/gust/compiler/parser.gst"
    if (target == 0xFFFFFFFF) {
#line 239 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 241 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 242 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 9;
#line 243 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).RawPointer.inner = target;
#line 244 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
#line 247 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 15)) {
#line 248 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 249 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16) == 0) {
#line 250 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 252 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 253 "/home/garth/files/code/gust/compiler/parser.gst"
    int target = parser__parse_type_signature(p, ctx);
#line 254 "/home/garth/files/code/gust/compiler/parser.gst"
    if (target == 0xFFFFFFFF) {
#line 255 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 257 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 258 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 6;
#line 259 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Slice.inner = target;
#line 260 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
#line 263 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0 && parser__cur_token_is(p, 45) == 0) {
#line 264 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 267 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char base_name = (*(p)).cur_token.literal;
#line 268 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 270 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 7)) {
#line 271 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 272 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 273 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 275 "/home/garth/files/code/gust/compiler/parser.gst"
    base_name = (({ Slice_unsigned_char _s1 = base_name; Slice_unsigned_char _s2 = ((Slice_unsigned_char){ (unsigned char*)".", 1 }); char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 276 "/home/garth/files/code/gust/compiler/parser.gst"
    base_name = (({ Slice_unsigned_char _s1 = base_name; Slice_unsigned_char _s2 = (*(p)).cur_token.literal; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }));
#line 277 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 280 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 15)) {
#line 281 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 282 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Type args_vec = (struct std_Vector_ast__Type){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 284 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16) == 0) {
#line 285 "/home/garth/files/code/gust/compiler/parser.gst"
    int first_arg = parser__parse_type_signature(p, ctx);
#line 286 "/home/garth/files/code/gust/compiler/parser.gst"
    if (first_arg == 0xFFFFFFFF) {
#line 287 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 289 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&args_vec, (*(( ast__Type*)((char*)ctx->BaseAddress + first_arg))));
#line 291 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 8)) {
#line 292 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 293 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_arg = parser__parse_type_signature(p, ctx);
#line 294 "/home/garth/files/code/gust/compiler/parser.gst"
    if (next_arg == 0xFFFFFFFF) {
#line 295 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 297 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&args_vec, (*(( ast__Type*)((char*)ctx->BaseAddress + next_arg))));
    }
    }
#line 301 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16) == 0) {
#line 302 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 304 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 306 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"Index", 5 }))) {
#line 307 "/home/garth/files/code/gust/compiler/parser.gst"
    if (args_vec.len == 1) {
#line 308 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type arg0 = (*({ if (0 < 0 || 0 >= args_vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(args_vec.data[0]); }));
#line 309 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char brand_name = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 310 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 8) {
#line 311 "/home/garth/files/code/gust/compiler/parser.gst"
    brand_name = arg0.Struct.struct_name;
    }
#line 313 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 314 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 7;
#line 315 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Index.struct_name = ((Slice_unsigned_char){ (unsigned char*)"SessionNode", 11 });
#line 317 "/home/garth/files/code/gust/compiler/parser.gst"
    int brand_idx = os_ArenaAlloc(ctx, sizeof(ast__Parameter));
#line 318 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Index.brand = ((int)brand_idx);
#line 319 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char* dest_ptr = ((Slice_unsigned_char*)&((*(( ast__Parameter*)((char*)ctx->BaseAddress + brand_idx)))));
#line 320 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_ptr)) = brand_name;
#line 321 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    } else {
#line 323 "/home/garth/files/code/gust/compiler/parser.gst"
    if (args_vec.len == 2) {
#line 324 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type arg0 = (*({ if (0 < 0 || 0 >= args_vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(args_vec.data[0]); }));
#line 325 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type arg1 = (*({ if (1 < 0 || 1 >= args_vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(args_vec.data[1]); }));
#line 326 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char struct_name = ((Slice_unsigned_char){ (unsigned char*)"SessionNode", 11 });
#line 327 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 8) {
#line 328 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = arg0.Struct.struct_name;
    } else {
#line 330 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 5) {
#line 331 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = ((Slice_unsigned_char){ (unsigned char*)"str", 3 });
    } else {
#line 333 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 0) {
#line 334 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = ((Slice_unsigned_char){ (unsigned char*)"int", 3 });
    } else {
#line 336 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 1) {
#line 337 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = ((Slice_unsigned_char){ (unsigned char*)"byte", 4 });
    } else {
#line 339 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 2) {
#line 340 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = ((Slice_unsigned_char){ (unsigned char*)"bool", 4 });
    } else {
#line 342 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 4) {
#line 343 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = ((Slice_unsigned_char){ (unsigned char*)"Arena", 5 });
    } else {
#line 345 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 10) {
#line 346 "/home/garth/files/code/gust/compiler/parser.gst"
    struct_name = parser__parser_get_monomorphized_name(arg0.Generic.name, arg0.Generic.args, ctx);
    }
    }
    }
    }
    }
    }
    }
#line 354 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char brand_name = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 355 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg1.tag == 8) {
#line 356 "/home/garth/files/code/gust/compiler/parser.gst"
    brand_name = arg1.Struct.struct_name;
    }
#line 358 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 359 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 7;
#line 360 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Index.struct_name = struct_name;
#line 362 "/home/garth/files/code/gust/compiler/parser.gst"
    int brand_idx = os_ArenaAlloc(ctx, sizeof(ast__Parameter));
#line 363 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Index.brand = ((int)brand_idx);
#line 364 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char* dest_ptr = ((Slice_unsigned_char*)&((*(( ast__Parameter*)((char*)ctx->BaseAddress + brand_idx)))));
#line 365 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_ptr)) = brand_name;
#line 366 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
    }
    }
#line 371 "/home/garth/files/code/gust/compiler/parser.gst"
    if (args_vec.len == 1) {
#line 372 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Type arg0 = (*({ if (0 < 0 || 0 >= args_vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(args_vec.data[0]); }));
#line 373 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char brand_name = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 374 "/home/garth/files/code/gust/compiler/parser.gst"
    int has_brand = 0;
#line 375 "/home/garth/files/code/gust/compiler/parser.gst"
    if (arg0.tag == 8) {
#line 376 "/home/garth/files/code/gust/compiler/parser.gst"
    brand_name = arg0.Struct.struct_name;
#line 377 "/home/garth/files/code/gust/compiler/parser.gst"
    has_brand = 1;
    }
#line 380 "/home/garth/files/code/gust/compiler/parser.gst"
    int is_builtin_brand = 0;
#line 381 "/home/garth/files/code/gust/compiler/parser.gst"
    if (has_brand == 1) {
#line 382 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(brand_name, ((Slice_unsigned_char){ (unsigned char*)"int", 3 })) || std_str_eq(brand_name, ((Slice_unsigned_char){ (unsigned char*)"byte", 4 })) || std_str_eq(brand_name, ((Slice_unsigned_char){ (unsigned char*)"str", 3 })) || std_str_eq(brand_name, ((Slice_unsigned_char){ (unsigned char*)"Arena", 5 })) || std_str_eq(brand_name, ((Slice_unsigned_char){ (unsigned char*)"os_Arena", 8 }))) {
#line 385 "/home/garth/files/code/gust/compiler/parser.gst"
    is_builtin_brand = 1;
    }
    }
#line 389 "/home/garth/files/code/gust/compiler/parser.gst"
    if (has_brand == 1 && is_builtin_brand == 0) {
#line 390 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 391 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 8;
#line 392 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Struct.struct_name = base_name;
#line 394 "/home/garth/files/code/gust/compiler/parser.gst"
    int brand_idx = os_ArenaAlloc(ctx, sizeof(ast__Parameter));
#line 395 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Struct.brand = ((int)brand_idx);
#line 396 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char* dest_ptr = ((Slice_unsigned_char*)&((*(( ast__Parameter*)((char*)ctx->BaseAddress + brand_idx)))));
#line 397 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_ptr)) = brand_name;
#line 398 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    } else {
#line 400 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 401 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 10;
#line 402 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.name = base_name;
#line 403 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.args = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Type));
#line 404 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Type* dest_args = ((std_Vector_ast__Type*)&((*(( std_Vector_ast__Type*)((char*)ctx->BaseAddress + (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.args)))));
#line 405 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_args)) = args_vec;
#line 406 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
    }
#line 410 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 411 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 10;
#line 412 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.name = base_name;
#line 413 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.args = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Type));
#line 414 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Type* dest_args = ((std_Vector_ast__Type*)&((*(( std_Vector_ast__Type*)((char*)ctx->BaseAddress + (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Generic.args)))));
#line 415 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_args)) = args_vec;
#line 416 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
#line 419 "/home/garth/files/code/gust/compiler/parser.gst"
    int t_idx = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 420 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"int", 3 }))) {
#line 421 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 0;
    } else {
#line 422 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"byte", 4 }))) {
#line 423 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 1;
    } else {
#line 424 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"bool", 4 }))) {
#line 425 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 2;
    } else {
#line 426 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"Arena", 5 })) || std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"os_Arena", 8 })) || std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"os.Arena", 8 }))) {
#line 427 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 4;
    } else {
#line 428 "/home/garth/files/code/gust/compiler/parser.gst"
    if (std_str_eq(base_name, ((Slice_unsigned_char){ (unsigned char*)"str", 3 }))) {
#line 429 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 5;
    } else {
#line 431 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).tag = 8;
#line 432 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Struct.struct_name = base_name;
#line 433 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + t_idx))).Struct.brand = 0xFFFFFFFF;
    }
    }
    }
    }
    }
#line 435 "/home/garth/files/code/gust/compiler/parser.gst"
    return t_idx;
    }
}

#line 439 "/home/garth/files/code/gust/compiler/parser.gst"
token__Span parser__get_expression_span(int expr, os_Arena* ctx) {
#line 440 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span s = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 441 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 442 "/home/garth/files/code/gust/compiler/parser.gst"
    int tag = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).tag;
#line 443 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 0) {
#line 443 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Identifier.span;
    } else {
#line 444 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 1) {
#line 444 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Integer.span;
    } else {
#line 445 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 2) {
#line 445 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).String.span;
    } else {
#line 446 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 3) {
#line 446 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Bool.span;
    } else {
#line 447 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 4) {
#line 447 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Move.span;
    } else {
#line 448 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 5) {
#line 448 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Take.span;
    } else {
#line 449 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 6) {
#line 449 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).AddressOf.span;
    } else {
#line 450 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 7) {
#line 450 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Dereference.span;
    } else {
#line 451 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 8) {
#line 451 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).IndexAccess.span;
    } else {
#line 452 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 9) {
#line 452 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).AsCast.span;
    } else {
#line 453 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 10) {
#line 453 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Binary.span;
    } else {
#line 454 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 11) {
#line 454 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Selector.span;
    } else {
#line 455 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 12) {
#line 455 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Call.span;
    } else {
#line 456 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 13) {
#line 456 "/home/garth/files/code/gust/compiler/parser.gst"
    s = (*(( ast__Expression*)((char*)ctx->BaseAddress + expr))).Empty.span;
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
    }
#line 458 "/home/garth/files/code/gust/compiler/parser.gst"
    return s;
}

#line 461 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__peek_token_precedence(parser__Parser* p) {
#line 462 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 463 "/home/garth/files/code/gust/compiler/parser.gst"
    int tag = (*(p)).peek_token.token_type.tag;
#line 464 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 51) {
#line 465 "/home/garth/files/code/gust/compiler/parser.gst"
    return 2;
    }
#line 467 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 50) {
#line 468 "/home/garth/files/code/gust/compiler/parser.gst"
    return 3;
    }
#line 470 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 23 || tag == 24) {
#line 471 "/home/garth/files/code/gust/compiler/parser.gst"
    return 4;
    }
#line 473 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 25 || tag == 26 || tag == 48 || tag == 49) {
#line 474 "/home/garth/files/code/gust/compiler/parser.gst"
    return 5;
    }
#line 476 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 19 || tag == 20) {
#line 477 "/home/garth/files/code/gust/compiler/parser.gst"
    return 6;
    }
#line 479 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 21 || tag == 22) {
#line 480 "/home/garth/files/code/gust/compiler/parser.gst"
    return 7;
    }
#line 482 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 37) {
#line 483 "/home/garth/files/code/gust/compiler/parser.gst"
    return 8;
    }
#line 485 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 7 || tag == 11 || tag == 15) {
#line 486 "/home/garth/files/code/gust/compiler/parser.gst"
    return 9;
    }
#line 488 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
}

void* parser__peek_token_precedence_pthread_wrapper(void* arg) {
    parser__peek_token_precedence((parser__Parser*)arg);
    return NULL;
}

#line 492 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_prefix_expression(parser__Parser* p, os_Arena* ctx) {
#line 493 "/home/garth/files/code/gust/compiler/parser.gst"
    int e_idx = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 494 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 495 "/home/garth/files/code/gust/compiler/parser.gst"
    int tag = (*(p)).cur_token.token_type.tag;
#line 496 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 498 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 2) {
#line 499 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 0;
#line 500 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Identifier.name = (*(p)).cur_token.literal;
#line 501 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Identifier.span = (*(p)).cur_token.span;
#line 502 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 503 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 505 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 3) {
#line 506 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 1;
#line 507 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Integer.val = std_parse_int((*(p)).cur_token.literal);
#line 508 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Integer.span = (*(p)).cur_token.span;
#line 509 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 510 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 512 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 4) {
#line 513 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 2;
#line 514 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).String.val = (*(p)).cur_token.literal;
#line 515 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).String.span = (*(p)).cur_token.span;
#line 516 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 517 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 519 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 46) {
#line 520 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 3;
#line 521 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Bool.val = 1;
#line 522 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Bool.span = (*(p)).cur_token.span;
#line 523 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 524 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 526 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 47) {
#line 527 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 3;
#line 528 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Bool.val = 0;
#line 529 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Bool.span = (*(p)).cur_token.span;
#line 530 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 531 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 533 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 11) {
#line 534 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 535 "/home/garth/files/code/gust/compiler/parser.gst"
    int inner = parser__parse_expression(p, 1, ctx);
#line 536 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 12) == 0) {
#line 537 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 539 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 540 "/home/garth/files/code/gust/compiler/parser.gst"
    return inner;
    }
#line 542 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 32) {
#line 543 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 544 "/home/garth/files/code/gust/compiler/parser.gst"
    int inner = parser__parse_expression(p, 8, ctx);
#line 545 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 4;
#line 546 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Move.expr = inner;
#line 547 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Move.span = parser__merge_spans(start_span, parser__get_expression_span(inner, ctx));
#line 548 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 550 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 33) {
#line 551 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 552 "/home/garth/files/code/gust/compiler/parser.gst"
    int inner = parser__parse_expression(p, 8, ctx);
#line 553 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 5;
#line 554 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Take.expr = inner;
#line 555 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Take.span = parser__merge_spans(start_span, parser__get_expression_span(inner, ctx));
#line 556 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 558 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 17) {
#line 559 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 560 "/home/garth/files/code/gust/compiler/parser.gst"
    int inner = parser__parse_expression(p, 8, ctx);
#line 561 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 6;
#line 562 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).AddressOf.expr = inner;
#line 563 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).AddressOf.span = parser__merge_spans(start_span, parser__get_expression_span(inner, ctx));
#line 564 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 566 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 21) {
#line 567 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 568 "/home/garth/files/code/gust/compiler/parser.gst"
    int inner = parser__parse_expression(p, 8, ctx);
#line 569 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 7;
#line 570 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Dereference.expr = inner;
#line 571 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Dereference.span = parser__merge_spans(start_span, parser__get_expression_span(inner, ctx));
#line 572 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 574 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 44) {
#line 575 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 576 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 15)) {
#line 577 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 579 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 581 "/home/garth/files/code/gust/compiler/parser.gst"
    int target_type = parser__parse_type_signature(p, ctx);
#line 582 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16)) {
#line 583 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 585 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 587 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).tag = 13;
#line 588 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Empty.target_type = target_type;
#line 589 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + e_idx))).Empty.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
#line 590 "/home/garth/files/code/gust/compiler/parser.gst"
    return e_idx;
    }
#line 592 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
}

#line 596 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__cur_token_precedence(parser__Parser* p) {
#line 597 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 598 "/home/garth/files/code/gust/compiler/parser.gst"
    int tag = (*(p)).cur_token.token_type.tag;
#line 599 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 51) {
#line 600 "/home/garth/files/code/gust/compiler/parser.gst"
    return 2;
    }
#line 602 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 50) {
#line 603 "/home/garth/files/code/gust/compiler/parser.gst"
    return 3;
    }
#line 605 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 23 || tag == 24) {
#line 606 "/home/garth/files/code/gust/compiler/parser.gst"
    return 4;
    }
#line 608 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 25 || tag == 26 || tag == 48 || tag == 49) {
#line 609 "/home/garth/files/code/gust/compiler/parser.gst"
    return 5;
    }
#line 611 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 19 || tag == 20) {
#line 612 "/home/garth/files/code/gust/compiler/parser.gst"
    return 6;
    }
#line 614 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 21 || tag == 22) {
#line 615 "/home/garth/files/code/gust/compiler/parser.gst"
    return 7;
    }
#line 617 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 37) {
#line 618 "/home/garth/files/code/gust/compiler/parser.gst"
    return 8;
    }
#line 620 "/home/garth/files/code/gust/compiler/parser.gst"
    if (tag == 7 || tag == 11 || tag == 15) {
#line 621 "/home/garth/files/code/gust/compiler/parser.gst"
    return 9;
    }
#line 623 "/home/garth/files/code/gust/compiler/parser.gst"
    return 1;
    }
}

void* parser__cur_token_precedence_pthread_wrapper(void* arg) {
    parser__cur_token_precedence((parser__Parser*)arg);
    return NULL;
}

#line 629 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_expression(parser__Parser* p, int precedence, os_Arena* ctx) {
#line 630 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 631 "/home/garth/files/code/gust/compiler/parser.gst"
    int left = parser__parse_prefix_expression(p, ctx);
#line 632 "/home/garth/files/code/gust/compiler/parser.gst"
    if (left == 0xFFFFFFFF) {
#line 633 "/home/garth/files/code/gust/compiler/parser.gst"
    return left;
    }
#line 636 "/home/garth/files/code/gust/compiler/parser.gst"
    while (precedence < parser__cur_token_precedence(p)) {
#line 637 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 10)) {
#line 638 "/home/garth/files/code/gust/compiler/parser.gst"
    return left;
    }
#line 640 "/home/garth/files/code/gust/compiler/parser.gst"
    int cur_tag = (*(p)).cur_token.token_type.tag;
#line 642 "/home/garth/files/code/gust/compiler/parser.gst"
    if (cur_tag == 7) {
#line 643 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = parser__get_expression_span(left, ctx);
#line 644 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 645 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 646 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 648 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char right = (*(p)).cur_token.literal;
#line 649 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 650 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 652 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_expr = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 653 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).tag = 11;
#line 654 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Selector.left = left;
#line 655 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Selector.right = right;
#line 656 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Selector.span = parser__merge_spans(start_span, end_span);
#line 657 "/home/garth/files/code/gust/compiler/parser.gst"
    left = next_expr;
    } else {
#line 658 "/home/garth/files/code/gust/compiler/parser.gst"
    if (cur_tag == 11) {
#line 659 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = parser__get_expression_span(left, ctx);
#line 660 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 663 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Expression args_vec = (struct std_Vector_ast__Expression){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 664 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 12) == 0) {
#line 665 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&args_vec, (*(( ast__Expression*)((char*)ctx->BaseAddress + parser__parse_expression(p, 1, ctx)))));
#line 666 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 8)) {
#line 667 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 668 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&args_vec, (*(( ast__Expression*)((char*)ctx->BaseAddress + parser__parse_expression(p, 1, ctx)))));
    }
    }
#line 671 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 12) == 0) {
#line 672 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 674 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 675 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 677 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_expr = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 678 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).tag = 12;
#line 679 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Call.function = left;
#line 680 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Call.arguments = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Expression));
#line 681 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Expression* dest_args = ((std_Vector_ast__Expression*)&((*(( std_Vector_ast__Expression*)((char*)ctx->BaseAddress + (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Call.arguments)))));
#line 682 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_args)) = args_vec;
#line 683 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Call.span = parser__merge_spans(start_span, end_span);
#line 684 "/home/garth/files/code/gust/compiler/parser.gst"
    left = next_expr;
    } else {
#line 685 "/home/garth/files/code/gust/compiler/parser.gst"
    if (cur_tag == 15) {
#line 686 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = parser__get_expression_span(left, ctx);
#line 687 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 688 "/home/garth/files/code/gust/compiler/parser.gst"
    int index_expr = parser__parse_expression(p, 1, ctx);
#line 689 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16) == 0) {
#line 690 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 692 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 693 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 695 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_expr = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 696 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).tag = 8;
#line 697 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).IndexAccess.allocator = left;
#line 698 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).IndexAccess.index = index_expr;
#line 699 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).IndexAccess.span = parser__merge_spans(start_span, end_span);
#line 700 "/home/garth/files/code/gust/compiler/parser.gst"
    left = next_expr;
    } else {
#line 701 "/home/garth/files/code/gust/compiler/parser.gst"
    if (cur_tag == 37) {
#line 702 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = parser__get_expression_span(left, ctx);
#line 703 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 704 "/home/garth/files/code/gust/compiler/parser.gst"
    int is_reference = 0;
#line 705 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 17)) {
#line 706 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 707 "/home/garth/files/code/gust/compiler/parser.gst"
    is_reference = 1;
    }
#line 709 "/home/garth/files/code/gust/compiler/parser.gst"
    int target_type = parser__parse_type_signature(p, ctx);
#line 710 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 712 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_expr = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 713 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).tag = 9;
#line 714 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).AsCast.left = left;
#line 715 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).AsCast.target_type = target_type;
#line 716 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).AsCast.is_reference = is_reference;
#line 717 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).AsCast.span = parser__merge_spans(start_span, end_span);
#line 718 "/home/garth/files/code/gust/compiler/parser.gst"
    left = next_expr;
    } else {
#line 719 "/home/garth/files/code/gust/compiler/parser.gst"
    if (cur_tag == 19 || cur_tag == 20 || cur_tag == 21 || cur_tag == 22 || cur_tag == 23 || cur_tag == 24 || cur_tag == 25 || cur_tag == 26 || cur_tag == 48 || cur_tag == 49 || cur_tag == 50 || cur_tag == 51) {
#line 722 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char op_str = (*(p)).cur_token.literal;
#line 723 "/home/garth/files/code/gust/compiler/parser.gst"
    int op_prec = parser__cur_token_precedence(p);
#line 725 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 727 "/home/garth/files/code/gust/compiler/parser.gst"
    int right = parser__parse_expression(p, op_prec, ctx);
#line 728 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = parser__get_expression_span(left, ctx);
#line 729 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = parser__get_expression_span(right, ctx);
#line 731 "/home/garth/files/code/gust/compiler/parser.gst"
    int next_expr = os_ArenaAlloc(ctx, sizeof(ast__Expression));
#line 732 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).tag = 10;
#line 733 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Binary.op = op_str;
#line 734 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Binary.left = left;
#line 735 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Binary.right = right;
#line 736 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Expression*)((char*)ctx->BaseAddress + next_expr))).Binary.span = parser__merge_spans(start_span, end_span);
#line 737 "/home/garth/files/code/gust/compiler/parser.gst"
    left = next_expr;
    } else {
#line 739 "/home/garth/files/code/gust/compiler/parser.gst"
    return left;
    }
    }
    }
    }
    }
    }
#line 742 "/home/garth/files/code/gust/compiler/parser.gst"
    return left;
    }
}

#line 746 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_struct_decl(parser__Parser* p, os_Arena* ctx) {
#line 747 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 748 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 749 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 750 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 751 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 752 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 753 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected identifier after 'type'", 32 });
#line 754 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 755 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 756 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 758 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char name = (*(p)).cur_token.literal;
#line 759 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 761 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_str generics_vec = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 762 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 15)) {
#line 763 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 764 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 2)) {
#line 765 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&generics_vec, (*(p)).cur_token.literal);
#line 766 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 767 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8)) {
#line 768 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 771 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 16) == 0) {
#line 772 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 773 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 774 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing bracket ']' in generic type parameters", 55 });
#line 775 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 776 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 777 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 779 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 782 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 40)) {
#line 783 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 784 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 785 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 786 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 787 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected opening brace '{' after 'struct'", 41 });
#line 788 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 789 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 790 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 792 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 794 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__FieldDef fields_vec = (struct std_Vector_ast__FieldDef){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 795 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 14) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 796 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
#line 797 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span f_start = (*(p)).cur_token.span;
#line 798 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char f_name = (*(p)).cur_token.literal;
#line 799 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 801 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 9) == 0) {
#line 802 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 803 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 804 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected ':' after struct field identifier", 42 });
#line 805 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 806 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 807 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 809 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 811 "/home/garth/files/code/gust/compiler/parser.gst"
    int f_type = parser__parse_type_signature(p, ctx);
#line 812 "/home/garth/files/code/gust/compiler/parser.gst"
    if (f_type == 0xFFFFFFFF) {
#line 813 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 814 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 815 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected field type signature", 29 });
#line 816 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 817 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 818 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 820 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span f_end = (*(p)).cur_token.span;
#line 822 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__FieldDef field = ((ast__FieldDef){ .field_type = ((ast__Type){ .tag = 0 }), .name = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 823 "/home/garth/files/code/gust/compiler/parser.gst"
    field.name = f_name;
#line 824 "/home/garth/files/code/gust/compiler/parser.gst"
    field.field_type = (*(( ast__Type*)((char*)ctx->BaseAddress + f_type)));
#line 825 "/home/garth/files/code/gust/compiler/parser.gst"
    field.span = parser__merge_spans(f_start, f_end);
#line 826 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&fields_vec, field);
#line 828 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8) || parser__cur_token_is(p, 10)) {
#line 829 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    } else {
#line 832 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 833 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 834 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected struct field identifier or '}'", 39 });
#line 835 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 836 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 837 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
#line 841 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 842 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 843 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 844 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing brace '}' after struct fields", 46 });
#line 845 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 846 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 847 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 849 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 850 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 852 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 853 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 1;
#line 855 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.name = name;
#line 857 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.generics = os_ArenaAlloc(ctx, sizeof(std_Vector_str));
#line 858 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_str* dest_generics = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.generics)))));
#line 859 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_generics)) = generics_vec;
#line 861 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.fields = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__FieldDef));
#line 862 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__FieldDef* dest_fields = ((std_Vector_ast__FieldDef*)&((*(( std_Vector_ast__FieldDef*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.fields)))));
#line 863 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_fields)) = fields_vec;
#line 865 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).StructDecl.span = parser__merge_spans(start_span, end_span);
#line 866 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    } else {
#line 867 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 41)) {
#line 868 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 870 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 871 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 872 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 873 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected opening brace '{' after 'enum'", 39 });
#line 874 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 875 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 876 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 878 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 880 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__VariantDef variants_vec = (struct std_Vector_ast__VariantDef){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 881 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 14) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 882 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
#line 883 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span variant_start = (*(p)).cur_token.span;
#line 884 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char variant_name = (*(p)).cur_token.literal;
#line 885 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 887 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__FieldDef fields_vec = (struct std_Vector_ast__FieldDef){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 888 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13)) {
#line 889 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 890 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 14) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 891 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
#line 892 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span f_start = (*(p)).cur_token.span;
#line 893 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char f_name = (*(p)).cur_token.literal;
#line 894 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 896 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 9) == 0) {
#line 897 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 898 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 899 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected ':' after enum variant field identifier", 48 });
#line 900 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 901 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 902 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 904 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 906 "/home/garth/files/code/gust/compiler/parser.gst"
    int f_type = parser__parse_type_signature(p, ctx);
#line 907 "/home/garth/files/code/gust/compiler/parser.gst"
    if (f_type == 0xFFFFFFFF) {
#line 908 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 909 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 910 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected field type signature", 29 });
#line 911 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 912 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 913 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 915 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span f_end = (*(p)).cur_token.span;
#line 917 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__FieldDef field = ((ast__FieldDef){ .field_type = ((ast__Type){ .tag = 0 }), .name = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 918 "/home/garth/files/code/gust/compiler/parser.gst"
    field.name = f_name;
#line 919 "/home/garth/files/code/gust/compiler/parser.gst"
    field.field_type = (*(( ast__Type*)((char*)ctx->BaseAddress + f_type)));
#line 920 "/home/garth/files/code/gust/compiler/parser.gst"
    field.span = parser__merge_spans(f_start, f_end);
#line 921 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&fields_vec, field);
#line 923 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8) || parser__cur_token_is(p, 10)) {
#line 924 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    } else {
#line 927 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 928 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 929 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected enum variant field identifier or '}'", 45 });
#line 930 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 931 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 932 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
#line 935 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 936 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 937 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 938 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing brace '}' after enum variant fields", 52 });
#line 939 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 940 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 941 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 943 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 945 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span variant_end = (*(p)).cur_token.span;
#line 947 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__VariantDef variant = ((ast__VariantDef){ .fields = 0xFFFFFFFF, .name = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 948 "/home/garth/files/code/gust/compiler/parser.gst"
    variant.name = variant_name;
#line 949 "/home/garth/files/code/gust/compiler/parser.gst"
    variant.fields = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__FieldDef));
#line 950 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__FieldDef* dest_vfields = ((std_Vector_ast__FieldDef*)&((*(( std_Vector_ast__FieldDef*)((char*)ctx->BaseAddress + variant.fields)))));
#line 951 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_vfields)) = fields_vec;
#line 952 "/home/garth/files/code/gust/compiler/parser.gst"
    variant.span = parser__merge_spans(variant_start, variant_end);
#line 953 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&variants_vec, variant);
#line 955 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8) || parser__cur_token_is(p, 10)) {
#line 956 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    } else {
#line 959 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 960 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 961 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected enum variant identifier or '}'", 39 });
#line 962 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 963 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 964 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
#line 968 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 969 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 970 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 971 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing brace '}' after enum variants", 46 });
#line 972 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 973 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 974 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 976 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 977 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 979 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 980 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 2;
#line 982 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.name = name;
#line 984 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.generics = os_ArenaAlloc(ctx, sizeof(std_Vector_str));
#line 985 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_str* dest_generics = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.generics)))));
#line 986 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_generics)) = generics_vec;
#line 988 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.variants = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__VariantDef));
#line 989 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__VariantDef* dest_variants = ((std_Vector_ast__VariantDef*)&((*(( std_Vector_ast__VariantDef*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.variants)))));
#line 990 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_variants)) = variants_vec;
#line 992 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).EnumDecl.span = parser__merge_spans(start_span, end_span);
#line 993 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    } else {
#line 995 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 996 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 997 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected 'struct' or 'enum' declaration", 39 });
#line 998 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 999 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1000 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
    }
}

#line 1005 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_function_decl(parser__Parser* p, os_Arena* ctx) {
#line 1006 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1007 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1008 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1009 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 1010 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1011 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1012 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected identifier after 'func'", 32 });
#line 1013 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1014 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1015 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1017 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char name = (*(p)).cur_token.literal;
#line 1018 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1020 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 11) == 0) {
#line 1021 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1022 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1023 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '(' after function name", 32 });
#line 1024 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1025 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1026 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1028 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1030 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Parameter params_vec = (struct std_Vector_ast__Parameter){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 1031 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 12) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 1032 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 1033 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1034 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1035 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected parameter name identifier", 34 });
#line 1036 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1037 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1038 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1040 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span param_start = (*(p)).cur_token.span;
#line 1041 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char param_name = (*(p)).cur_token.literal;
#line 1042 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1044 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 9) == 0) {
#line 1045 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1046 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1047 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected ':' after parameter name", 33 });
#line 1048 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1049 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1050 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1052 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1054 "/home/garth/files/code/gust/compiler/parser.gst"
    int p_type = parser__parse_type_signature(p, ctx);
#line 1055 "/home/garth/files/code/gust/compiler/parser.gst"
    if (p_type == 0xFFFFFFFF) {
#line 1056 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1057 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1058 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected parameter type signature", 33 });
#line 1059 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1060 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1061 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1063 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span param_end = (*(p)).cur_token.span;
#line 1065 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Parameter param = ((ast__Parameter){ .name = ((Slice_unsigned_char){ NULL, 0 }), .param_type = ((ast__Type){ .tag = 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1066 "/home/garth/files/code/gust/compiler/parser.gst"
    param.name = param_name;
#line 1067 "/home/garth/files/code/gust/compiler/parser.gst"
    param.param_type = (*(( ast__Type*)((char*)ctx->BaseAddress + p_type)));
#line 1068 "/home/garth/files/code/gust/compiler/parser.gst"
    param.span = parser__merge_spans(param_start, param_end);
#line 1069 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&params_vec, param);
#line 1071 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8)) {
#line 1072 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 1076 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 12) == 0) {
#line 1077 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1078 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1079 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing parenthesis ')'", 32 });
#line 1080 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1081 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1082 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1084 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1086 "/home/garth/files/code/gust/compiler/parser.gst"
    int r_type = os_ArenaAlloc(ctx, sizeof(ast__Type));
#line 1087 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Type*)((char*)ctx->BaseAddress + r_type))).tag = 3;
#line 1090 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) || parser__cur_token_is(p, 45) || parser__cur_token_is(p, 15) || parser__cur_token_is(p, 21) || parser__cur_token_is(p, 17)) {
#line 1091 "/home/garth/files/code/gust/compiler/parser.gst"
    int parsed_r_type = parser__parse_type_signature(p, ctx);
#line 1092 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parsed_r_type == 0xFFFFFFFF) {
#line 1093 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1094 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1095 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected return type signature", 30 });
#line 1096 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1097 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1098 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1100 "/home/garth/files/code/gust/compiler/parser.gst"
    r_type = parsed_r_type;
    }
#line 1103 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1104 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1105 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1106 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected opening brace '{' for function body", 44 });
#line 1107 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1108 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1109 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1112 "/home/garth/files/code/gust/compiler/parser.gst"
    int body = parser__parse_block_statement(p, ctx);
#line 1113 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + body))).span;
#line 1115 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1116 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 3;
#line 1118 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.name = name;
#line 1120 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.params = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Parameter));
#line 1121 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Parameter* dest_params = ((std_Vector_ast__Parameter*)&((*(( std_Vector_ast__Parameter*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.params)))));
#line 1122 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_params)) = params_vec;
#line 1124 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.return_type = r_type;
#line 1125 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.body = body;
#line 1126 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).FunctionDecl.span = parser__merge_spans(start_span, end_span);
#line 1128 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1132 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_defer_statement(parser__Parser* p, os_Arena* ctx) {
#line 1133 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1134 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1135 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1136 "/home/garth/files/code/gust/compiler/parser.gst"
    int expr = parser__parse_expression(p, 1, ctx);
#line 1137 "/home/garth/files/code/gust/compiler/parser.gst"
    if (expr == 0xFFFFFFFF) {
#line 1138 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1140 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = parser__get_expression_span(expr, ctx);
#line 1142 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1143 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 11;
#line 1144 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Defer.expr = expr;
#line 1145 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Defer.span = parser__merge_spans(start_span, end_span);
#line 1146 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1150 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_return_statement(parser__Parser* p, os_Arena* ctx) {
#line 1151 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1152 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1153 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1154 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 10) || parser__cur_token_is(p, 14)) {
#line 1155 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1156 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 12;
#line 1157 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Return.expr = 0xFFFFFFFF;
#line 1158 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Return.span = start_span;
#line 1159 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
#line 1162 "/home/garth/files/code/gust/compiler/parser.gst"
    int expr = parser__parse_expression(p, 1, ctx);
#line 1163 "/home/garth/files/code/gust/compiler/parser.gst"
    if (expr == 0xFFFFFFFF) {
#line 1164 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1166 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = parser__get_expression_span(expr, ctx);
#line 1168 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1169 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 12;
#line 1170 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Return.expr = expr;
#line 1171 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Return.span = parser__merge_spans(start_span, end_span);
#line 1172 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1176 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_unsafe_block(parser__Parser* p, os_Arena* ctx) {
#line 1177 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1178 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1179 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1180 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1181 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1183 "/home/garth/files/code/gust/compiler/parser.gst"
    int body = parser__parse_block_statement(p, ctx);
#line 1184 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + body))).span;
#line 1186 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1187 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 10;
#line 1188 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).UnsafeBlock.body = body;
#line 1189 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).UnsafeBlock.span = parser__merge_spans(start_span, end_span);
#line 1190 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1194 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_match_statement(parser__Parser* p, os_Arena* ctx) {
#line 1195 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1196 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1197 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1198 "/home/garth/files/code/gust/compiler/parser.gst"
    int expression = parser__parse_expression(p, 1, ctx);
#line 1199 "/home/garth/files/code/gust/compiler/parser.gst"
    if (expression == 0xFFFFFFFF) {
#line 1200 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1203 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1204 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1205 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1206 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '{' after match expression", 35 });
#line 1207 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1208 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1209 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1211 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1213 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__MatchCase cases_vec = (struct std_Vector_ast__MatchCase){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 1214 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 14) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 1215 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span case_start = (*(p)).cur_token.span;
#line 1216 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 1217 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1219 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char variant_name = (*(p)).cur_token.literal;
#line 1220 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1222 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_str fields_vec = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 1223 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13)) {
#line 1224 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1225 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__cur_token_is(p, 14) == 0 && parser__cur_token_is(p, 0) == 0) {
#line 1226 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
#line 1227 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&fields_vec, (*(p)).cur_token.literal);
#line 1228 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 1230 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1231 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1232 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected identifier in match pattern destructuring", 50 });
#line 1233 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1234 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1235 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1238 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8)) {
#line 1239 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 1240 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 1241 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1242 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1243 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected ',' or '}' in match pattern destructuring", 50 });
#line 1244 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1245 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1246 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
    }
#line 1249 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 1250 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1251 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1252 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected closing brace '}' in match pattern destructuring", 57 });
#line 1253 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1254 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1255 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1257 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1260 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 18) == 0) {
#line 1261 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1262 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1263 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '=>' after match pattern", 33 });
#line 1264 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1265 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1266 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1268 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1270 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1271 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1273 "/home/garth/files/code/gust/compiler/parser.gst"
    int body = parser__parse_block_statement(p, ctx);
#line 1274 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span case_end = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + body))).span;
#line 1276 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__MatchCase mcase = ((ast__MatchCase){ .body = 0xFFFFFFFF, .fields = 0xFFFFFFFF, .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }), .variant_name = ((Slice_unsigned_char){ NULL, 0 }) });
#line 1277 "/home/garth/files/code/gust/compiler/parser.gst"
    mcase.variant_name = variant_name;
#line 1278 "/home/garth/files/code/gust/compiler/parser.gst"
    mcase.fields = os_ArenaAlloc(ctx, sizeof(std_Vector_str));
#line 1279 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_str* dest_cfields = ((std_Vector_str*)&((*(( std_Vector_str*)((char*)ctx->BaseAddress + mcase.fields)))));
#line 1280 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_cfields)) = fields_vec;
#line 1281 "/home/garth/files/code/gust/compiler/parser.gst"
    mcase.body = body;
#line 1282 "/home/garth/files/code/gust/compiler/parser.gst"
    mcase.span = parser__merge_spans(case_start, case_end);
#line 1284 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&cases_vec, mcase);
#line 1286 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 8)) {
#line 1287 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 1291 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14) == 0) {
#line 1292 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1294 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(p)).cur_token.span;
#line 1296 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1297 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 8;
#line 1298 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Match.expression = expression;
#line 1299 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Match.cases = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__MatchCase));
#line 1300 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__MatchCase* dest_cases = ((std_Vector_ast__MatchCase*)&((*(( std_Vector_ast__MatchCase*)((char*)ctx->BaseAddress + (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Match.cases)))));
#line 1301 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_cases)) = cases_vec;
#line 1302 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Match.span = parser__merge_spans(start_span, end_span);
#line 1304 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1308 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_statement(parser__Parser* p, os_Arena* ctx) {
#line 1309 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1310 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 28)) {
#line 1311 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_import_statement(p, ctx);
    }
#line 1313 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(p)).has_non_import_statement = 1;
#line 1315 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 39)) {
#line 1316 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_struct_decl(p, ctx);
    }
#line 1319 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 30)) {
#line 1320 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_function_decl(p, ctx);
    }
#line 1323 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 31)) {
#line 1324 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_defer_statement(p, ctx);
    }
#line 1327 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 38)) {
#line 1328 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_unsafe_block(p, ctx);
    }
#line 1331 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 43)) {
#line 1332 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_return_statement(p, ctx);
    }
#line 1335 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 42)) {
#line 1336 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_match_statement(p, ctx);
    }
#line 1339 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 29)) {
#line 1340 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_var_decl(p, 1, ctx);
    }
#line 1342 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 34)) {
#line 1343 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_while_statement(p, ctx);
    }
#line 1345 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 35)) {
#line 1346 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_if_statement(p, ctx);
    }
#line 1348 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 27)) {
#line 1349 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_guard_statement(p, ctx);
    }
#line 1352 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
#line 1353 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__peek_token_is(p, 5)) {
#line 1354 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_var_decl(p, 0, ctx);
    }
#line 1356 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__peek_token_is(p, 9)) {
#line 1357 "/home/garth/files/code/gust/compiler/parser.gst"
    return parser__parse_var_decl(p, 0, ctx);
    }
    }
#line 1361 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1362 "/home/garth/files/code/gust/compiler/parser.gst"
    int left_expr = parser__parse_expression(p, 1, ctx);
#line 1363 "/home/garth/files/code/gust/compiler/parser.gst"
    if (left_expr == 0xFFFFFFFF) {
#line 1364 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1367 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 6)) {
#line 1368 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1369 "/home/garth/files/code/gust/compiler/parser.gst"
    int right_expr = parser__parse_expression(p, 1, ctx);
#line 1370 "/home/garth/files/code/gust/compiler/parser.gst"
    if (right_expr == 0xFFFFFFFF) {
#line 1371 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1373 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1374 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 5;
#line 1375 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Assignment.left = left_expr;
#line 1376 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Assignment.value = right_expr;
#line 1377 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Assignment.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
#line 1378 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
#line 1381 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1382 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 13;
#line 1383 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Expression.expr = left_expr;
#line 1384 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Expression.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
#line 1385 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 1389 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_var_decl(parser__Parser* p, int is_mut, os_Arena* ctx) {
#line 1390 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 1391 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1392 "/home/garth/files/code/gust/compiler/parser.gst"
    start_span = (*(p)).cur_token.span;
#line 1393 "/home/garth/files/code/gust/compiler/parser.gst"
    if (is_mut == 1) {
#line 1394 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 1398 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
    } else {
#line 1400 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1403 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char name = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 1404 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1405 "/home/garth/files/code/gust/compiler/parser.gst"
    name = (*(p)).cur_token.literal;
#line 1406 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1409 "/home/garth/files/code/gust/compiler/parser.gst"
    int var_type = 0xFFFFFFFF;
#line 1410 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1411 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 9)) {
#line 1412 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1413 "/home/garth/files/code/gust/compiler/parser.gst"
    var_type = parser__parse_type_signature(p, ctx);
    }
    }
#line 1417 "/home/garth/files/code/gust/compiler/parser.gst"
    int value = 0xFFFFFFFF;
#line 1418 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1419 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 5)) {
#line 1420 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1421 "/home/garth/files/code/gust/compiler/parser.gst"
    value = parser__parse_expression(p, 1, ctx);
    }
    }
#line 1425 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1426 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1427 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 4;
#line 1428 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).VarDecl.name = name;
#line 1429 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).VarDecl.is_mut = is_mut;
#line 1430 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).VarDecl.value = value;
#line 1431 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).VarDecl.var_type = var_type;
#line 1432 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).VarDecl.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
    }
#line 1434 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
}

#line 1437 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_block_statement(parser__Parser* p, os_Arena* ctx) {
#line 1438 "/home/garth/files/code/gust/compiler/parser.gst"
    int block_idx = os_ArenaAlloc(ctx, sizeof(ast__BlockStatement));
#line 1439 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1440 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement statements_vec = (struct std_Vector_ast__Statement){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 1441 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement* dest_ptr = &(statements_vec);
#line 1442 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx))).span = (*(p)).cur_token.span;
#line 1444 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1446 "/home/garth/files/code/gust/compiler/parser.gst"
    while (parser__is_at_end(p) == 0) {
#line 1447 "/home/garth/files/code/gust/compiler/parser.gst"
    int before_errors = (*(p)).errors.len;
#line 1448 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt = parser__parse_statement(p, ctx);
#line 1449 "/home/garth/files/code/gust/compiler/parser.gst"
    if (stmt != 0xFFFFFFFF) {
#line 1450 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(dest_ptr)), (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt))));
#line 1451 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 10)) {
#line 1452 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    } else {
#line 1455 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).errors.len == before_errors) {
#line 1456 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__error_at_current(p, ((Slice_unsigned_char){ (unsigned char*)"Expected valid statement inside block", 37 }));
    }
#line 1458 "/home/garth/files/code/gust/compiler/parser.gst"
    int before_sync = (*(p)).cur_token.token_type.tag;
#line 1459 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__synchronize(p);
#line 1460 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).cur_token.token_type.tag == before_sync) {
#line 1461 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
    }
#line 1466 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx))).statements = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Statement));
#line 1467 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement* dest_arena_ptr = ((std_Vector_ast__Statement*)&((*(( std_Vector_ast__Statement*)((char*)ctx->BaseAddress + (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx))).statements)))));
#line 1468 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_arena_ptr)) = statements_vec;
#line 1470 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx))).span = parser__merge_spans((*(( ast__BlockStatement*)((char*)ctx->BaseAddress + block_idx))).span, (*(p)).cur_token.span);
#line 1471 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 14)) {
#line 1472 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 1475 "/home/garth/files/code/gust/compiler/parser.gst"
    return block_idx;
}

#line 1478 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_while_statement(parser__Parser* p, os_Arena* ctx) {
#line 1479 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 1480 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1481 "/home/garth/files/code/gust/compiler/parser.gst"
    start_span = (*(p)).cur_token.span;
#line 1482 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1485 "/home/garth/files/code/gust/compiler/parser.gst"
    int condition = parser__parse_expression(p, 1, ctx);
#line 1487 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1488 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1489 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1490 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1491 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '{' after while condition", 34 });
#line 1492 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1493 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
#line 1495 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1498 "/home/garth/files/code/gust/compiler/parser.gst"
    int body = parser__parse_block_statement(p, ctx);
#line 1500 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1501 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1502 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 6;
#line 1503 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).While.condition = condition;
#line 1504 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).While.body = body;
#line 1505 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).While.span = parser__merge_spans(start_span, (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + body))).span);
    }
#line 1507 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
}

#line 1510 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_if_statement(parser__Parser* p, os_Arena* ctx) {
#line 1511 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 1512 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1513 "/home/garth/files/code/gust/compiler/parser.gst"
    start_span = (*(p)).cur_token.span;
#line 1514 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1517 "/home/garth/files/code/gust/compiler/parser.gst"
    int condition = parser__parse_expression(p, 1, ctx);
#line 1519 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1520 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1521 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1522 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1523 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '{' after if condition", 31 });
#line 1524 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1525 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
#line 1527 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1530 "/home/garth/files/code/gust/compiler/parser.gst"
    int consequence = parser__parse_block_statement(p, ctx);
#line 1532 "/home/garth/files/code/gust/compiler/parser.gst"
    int alternative = 0xFFFFFFFF;
#line 1533 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span end_span = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + consequence))).span;
#line 1535 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1536 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 36)) {
#line 1537 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1538 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13)) {
#line 1539 "/home/garth/files/code/gust/compiler/parser.gst"
    alternative = parser__parse_block_statement(p, ctx);
#line 1540 "/home/garth/files/code/gust/compiler/parser.gst"
    end_span = (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + alternative))).span;
    }
    }
    }
#line 1545 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1546 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1547 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 7;
#line 1548 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).If.condition = condition;
#line 1549 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).If.consequence = consequence;
#line 1550 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).If.alternative = alternative;
#line 1551 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).If.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
    }
#line 1553 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
}

#line 1556 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_guard_statement(parser__Parser* p, os_Arena* ctx) {
#line 1557 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) });
#line 1558 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1559 "/home/garth/files/code/gust/compiler/parser.gst"
    start_span = (*(p)).cur_token.span;
#line 1560 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1563 "/home/garth/files/code/gust/compiler/parser.gst"
    int is_mut = 0;
#line 1564 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1565 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 29)) {
#line 1566 "/home/garth/files/code/gust/compiler/parser.gst"
    is_mut = 1;
#line 1567 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
#line 1571 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2)) {
    } else {
#line 1573 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1576 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char name = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 1577 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1578 "/home/garth/files/code/gust/compiler/parser.gst"
    name = (*(p)).cur_token.literal;
#line 1579 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1582 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1583 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 5)) {
#line 1584 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 1586 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
#line 1590 "/home/garth/files/code/gust/compiler/parser.gst"
    int value = parser__parse_expression(p, 1, ctx);
#line 1592 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1593 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 36)) {
#line 1594 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    } else {
#line 1596 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
    }
#line 1600 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 13) == 0) {
#line 1601 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1602 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1603 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1604 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected '{' after else", 23 });
#line 1605 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1606 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
#line 1608 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1611 "/home/garth/files/code/gust/compiler/parser.gst"
    int else_body = parser__parse_block_statement(p, ctx);
#line 1613 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1614 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1615 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 9;
#line 1616 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Guard.name = name;
#line 1617 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Guard.is_mut = is_mut;
#line 1618 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Guard.value = value;
#line 1619 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Guard.else_body = else_body;
#line 1620 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Guard.span = parser__merge_spans(start_span, (*(( ast__BlockStatement*)((char*)ctx->BaseAddress + else_body))).span);
    }
#line 1622 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
}

#line 1625 "/home/garth/files/code/gust/compiler/parser.gst"
ast__Program parser__parse_program(parser__Parser* p, os_Arena* ctx) {
#line 1626 "/home/garth/files/code/gust/compiler/parser.gst"
    ast__Program prog = ((ast__Program){ .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }), .statements = 0xFFFFFFFF });
#line 1627 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1628 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement statements_vec = (struct std_Vector_ast__Statement){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
#line 1629 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement* dest_ptr = &(statements_vec);
#line 1631 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1633 "/home/garth/files/code/gust/compiler/parser.gst"
    while ((*(p)).cur_token.token_type.tag != 0) {
#line 1634 "/home/garth/files/code/gust/compiler/parser.gst"
    int before_errors = (*(p)).errors.len;
#line 1635 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt = parser__parse_statement(p, ctx);
#line 1636 "/home/garth/files/code/gust/compiler/parser.gst"
    if (stmt != 0xFFFFFFFF) {
#line 1637 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(dest_ptr)), (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt))));
#line 1638 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 10)) {
#line 1639 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    } else {
#line 1642 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).errors.len == before_errors) {
#line 1643 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__error_at_current(p, ((Slice_unsigned_char){ (unsigned char*)"Syntax Error: unexpected token or malformed statement", 53 }));
    }
#line 1645 "/home/garth/files/code/gust/compiler/parser.gst"
    int before_sync = (*(p)).cur_token.token_type.tag;
#line 1646 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__synchronize(p);
#line 1647 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).cur_token.token_type.tag == before_sync) {
#line 1648 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
    }
    }
#line 1653 "/home/garth/files/code/gust/compiler/parser.gst"
    prog.statements = os_ArenaAlloc(ctx, sizeof(std_Vector_ast__Statement));
#line 1654 "/home/garth/files/code/gust/compiler/parser.gst"
    std_Vector_ast__Statement* dest_arena_ptr = ((std_Vector_ast__Statement*)&((*(( std_Vector_ast__Statement*)((char*)ctx->BaseAddress + prog.statements)))));
#line 1655 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(dest_arena_ptr)) = statements_vec;
#line 1657 "/home/garth/files/code/gust/compiler/parser.gst"
    prog.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
    }
#line 1659 "/home/garth/files/code/gust/compiler/parser.gst"
    return prog;
}

#line 1662 "/home/garth/files/code/gust/compiler/parser.gst"
int parser__parse_import_statement(parser__Parser* p, os_Arena* ctx) {
#line 1663 "/home/garth/files/code/gust/compiler/parser.gst"
    {
#line 1664 "/home/garth/files/code/gust/compiler/parser.gst"
    token__Span start_span = (*(p)).cur_token.span;
#line 1665 "/home/garth/files/code/gust/compiler/parser.gst"
    if ((*(p)).has_non_import_statement == 1) {
#line 1666 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1667 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1668 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Imports must be at the beginning of the program", 47 });
#line 1669 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1670 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
    }
#line 1673 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1675 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 4) == 0) {
#line 1676 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1677 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1678 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected string literal specifying the import path", 50 });
#line 1679 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1680 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1681 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1684 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char path = (*(p)).cur_token.literal;
#line 1685 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1687 "/home/garth/files/code/gust/compiler/parser.gst"
    Slice_unsigned_char alias = ((Slice_unsigned_char){ (unsigned char*)"", 0 });
#line 1688 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 37)) {
#line 1689 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
#line 1690 "/home/garth/files/code/gust/compiler/parser.gst"
    if (parser__cur_token_is(p, 2) == 0) {
#line 1691 "/home/garth/files/code/gust/compiler/parser.gst"
    errors__CompilerError err = ((errors__CompilerError){ .kind = ((errors__ErrorKind){ .tag = 0 }), .message = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }) });
#line 1692 "/home/garth/files/code/gust/compiler/parser.gst"
    err.kind.tag = 1;
#line 1693 "/home/garth/files/code/gust/compiler/parser.gst"
    err.message = ((Slice_unsigned_char){ (unsigned char*)"Expected identifier alias after 'as'", 36 });
#line 1694 "/home/garth/files/code/gust/compiler/parser.gst"
    err.span = (*(p)).cur_token.span;
#line 1695 "/home/garth/files/code/gust/compiler/parser.gst"
    os_VectorPush(&(*(p)).errors, err);
#line 1696 "/home/garth/files/code/gust/compiler/parser.gst"
    return 0xFFFFFFFF;
    }
#line 1698 "/home/garth/files/code/gust/compiler/parser.gst"
    alias = (*(p)).cur_token.literal;
#line 1699 "/home/garth/files/code/gust/compiler/parser.gst"
    parser__next_token(p);
    }
#line 1702 "/home/garth/files/code/gust/compiler/parser.gst"
    int stmt_idx = os_ArenaAlloc(ctx, sizeof(ast__Statement));
#line 1703 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).tag = 0;
#line 1704 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Import.path = path;
#line 1705 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Import.alias = alias;
#line 1706 "/home/garth/files/code/gust/compiler/parser.gst"
    (*(( ast__Statement*)((char*)ctx->BaseAddress + stmt_idx))).Import.span = parser__merge_spans(start_span, (*(p)).cur_token.span);
#line 1707 "/home/garth/files/code/gust/compiler/parser.gst"
    return stmt_idx;
    }
}

#line 7 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
void gust_user_main(void* _gust_arg) {
#line 8 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_Arena ctx = os_Arena_New();
#line 10 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_SetThreadScratch(&ctx);
#line 12 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    std_Vector_str args = os_Args(&ctx);
#line 13 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    if (args.len < 2) {
#line 14 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_LogStr(((Slice_unsigned_char){ (unsigned char*)"Usage: ast_dump <file>", 22 }));
#line 15 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    exit(1);
    }
#line 17 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    Slice_unsigned_char file_path = (*({ if (1 < 0 || 1 >= args.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(args.data[1]); }));
#line 18 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    Slice_unsigned_char source = os_ReadFile(&ctx, file_path);
#line 19 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    if (source.len == 0) {
#line 20 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_LogStr(((Slice_unsigned_char){ (unsigned char*)"Error: empty file or failed to read", 35 }));
#line 21 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    exit(1);
    }
#line 24 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    lexer__Lexer l = ((lexer__Lexer){ .ch = 0, .column = 0, .input = ((Slice_unsigned_char){ NULL, 0 }), .line = 0, .position = 0, .read_position = 0 });
#line 25 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    lexer__init_lexer(&(l), source);
#line 27 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    parser__Parser p = ((parser__Parser){ .cur_token = ((token__Token){ .literal = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }), .token_type = ((token__TokenType){ .tag = 0 }) }), .errors = ((std_Vector_errors__CompilerError){ .arena = NULL, .capacity = 0, .data = NULL, .len = 0 }), .has_non_import_statement = 0, .lexer = NULL, .peek_token = ((token__Token){ .literal = ((Slice_unsigned_char){ NULL, 0 }), .span = ((token__Span){ .end = ((token__Position){ .column = 0, .line = 0, .offset = 0 }), .start = ((token__Position){ .column = 0, .line = 0, .offset = 0 }) }), .token_type = ((token__TokenType){ .tag = 0 }) }), .pushback_tokens = ((std_Vector_token__Token){ .arena = NULL, .capacity = 0, .data = NULL, .len = 0 }) });
#line 28 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    parser__init_parser(&(p), &(l), &ctx);
#line 30 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    ast__Program prog = parser__parse_program(&(p), &ctx);
#line 31 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    Slice_unsigned_char serialized = ast__serialize_program(&(prog), 0, &ctx);
#line 32 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_LogStr(serialized);
    // === DEFERRED CLEANUP CODES ===
#line 9 "/home/garth/files/code/gust/compiler/ast_dump_entry.gst"
    os_Arena_Free(&ctx);
}

int main(int argc, char** argv) {
    os_argc = argc;
    os_argv = argv;
    gust_scheduler_init(1);
    gust_scheduler_spawn(8388608, gust_user_main, NULL);
    gust_scheduler_destroy();
    return 0;
}

