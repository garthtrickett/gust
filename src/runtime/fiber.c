#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif
#include <poll.h>
#include <unistd.h>

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

int std_Mutex_Alloc() {
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

void* std_Mutex_Lock_impl(int lock_state, void* value_ptr) {
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

void std_Mutex_Unlock_impl(int lock_state) {
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

int std_Channel_Alloc(int capacity, size_t elem_size) {
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

void std_Channel_Send_impl(int chan_idx, void* val_ptr) {
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

void std_Channel_Recv_impl(int chan_idx, void* out_ptr) {
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
