#ifndef GUST_CORE_HEADERS_H
#define GUST_CORE_HEADERS_H

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

extern int os_argc;
extern char** os_argv;

typedef void* map_void_ptr;

typedef struct {
    void* BaseAddress;
    size_t Offset;
    size_t Capacity;
} os_Arena;

typedef struct {
    os_Arena* arena;
    int capacity;
    void* data;
    int free_len;
    int* free_list;
    int len;
    int* occupied;
} GenericPool;

// Standard Slice Structures
typedef struct Slice_unsigned_char Slice_unsigned_char;
struct Slice_unsigned_char {
    unsigned char* data;
    int len;
};

typedef struct Slice_int Slice_int;
struct Slice_int {
    int* data;
    int len;
};

// Complete structural definitions for the FFI standard library prototypes
typedef struct os_Dir os_Dir;
struct os_Dir {
    unsigned char* handle;
};

typedef struct os_DirEntry os_DirEntry;
struct os_DirEntry {
    int is_dir;
    Slice_unsigned_char name;
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

typedef struct std_Vector_str std_Vector_str;
struct std_Vector_str {
    Slice_unsigned_char* data;
    int len;
    int capacity;
    os_Arena* arena;
};

typedef struct std_GenerationalArena_Generic std_GenerationalArena_Generic;
struct std_GenerationalArena_Generic {
    os_Arena current_ctx;
    os_Arena next_ctx;
    int survivor;
};

// Standard Library collections FFI helper functions (defined in src/runtime.c)
void* os_HashMapRef_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size);
int os_HashMapContains_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size);
void os_HashMapRemove_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size);
void os_HashMapRemove_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size);
void os_HashMapClear_impl(void* map_void, size_t key_size, size_t val_size);
int std_PoolAlloc_impl(void* pool_void, size_t elem_size);
void std_PoolFree_impl(void* pool_void, int index);

// GUST COLLECTIONS OPERATIONS (VECTOR, HASHMAP, POOL & RC MACROS)
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
        if ((vec_ptr)->data != NULL && (vec_ptr)->len > 0) { \
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

// Core Runtime & FFI Function Prototypes
os_Arena os_Arena_New(void);
void os_SetThreadScratch(os_Arena* arena);
os_Arena* os_GetThreadScratch_raw(void);
void* os_ScratchAlloc(size_t size);
void os_ScratchReset(void);
int os_ArenaAlloc(os_Arena* arena, size_t size);
void os_Arena_Validate(os_Arena* arena);
void os_Arena_Free(os_Arena* arena);
void std_GenerationalSwap(os_Arena* current, os_Arena* next);

int std_Mutex_Alloc(void);
void* std_Mutex_Lock_impl(int lock_state, void* value_ptr);
void std_Mutex_Unlock_impl(int lock_state);

int std_Channel_Alloc(int capacity, size_t elem_size);
void std_Channel_Send_impl(int chan_idx, void* val_ptr);
void std_Channel_Recv_impl(int chan_idx, void* out_ptr);

int get_num_threads_to_use(void);
void gust_scheduler_init(int num_shards);
void gust_scheduler_spawn(size_t stack_size, void (*entry_fn)(void*), void* arg);
void gust_scheduler_destroy(void);
void gust_yield(void);

struct std_Vector_str os_Args(os_Arena* ctx);
struct Slice_unsigned_char os_MockPayload(void);
void os_LogStr(struct Slice_unsigned_char s);
void os_LogInt(int val);

int std_str_eq(struct Slice_unsigned_char s1, struct Slice_unsigned_char s2);
struct Slice_unsigned_char std_str_slice(struct Slice_unsigned_char s, int start, int end);
unsigned char std_str_byte_at(struct Slice_unsigned_char s, int idx);
int std_str_find(struct Slice_unsigned_char s, struct Slice_unsigned_char target);
struct Slice_unsigned_char std_str_trim(struct Slice_unsigned_char s);
struct std_Vector_str std_str_split(struct Slice_unsigned_char s, struct Slice_unsigned_char delim, os_Arena* ctx);

unsigned char std_is_alpha(unsigned char b);
unsigned char std_is_digit(unsigned char b);
unsigned char std_is_whitespace(unsigned char b);
int std_parse_int(struct Slice_unsigned_char s);

struct Slice_unsigned_char os_ReadFile(os_Arena* arena, struct Slice_unsigned_char path);
int os_WriteFile(struct Slice_unsigned_char path, struct Slice_unsigned_char contents);
struct LookupResult_os_Dir os_OpenDir(os_Arena* arena, struct Slice_unsigned_char path);
struct LookupResult_os_DirEntry os_ReadDir(os_Arena* arena, struct os_Dir dir);
void os_CloseDir(struct os_Dir dir);
struct Slice_unsigned_char os_path_join(struct Slice_unsigned_char dir, struct Slice_unsigned_char file, os_Arena* ctx);
struct Slice_unsigned_char std_Clone_str(os_Arena* arena, struct Slice_unsigned_char s);
int os_System(struct Slice_unsigned_char cmd);

#endif /* GUST_CORE_HEADERS_H */
