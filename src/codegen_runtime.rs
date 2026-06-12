pub const CORE_HEADERS: &str = r#"#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <sched.h>
#include <sys/types.h>
#include <dirent.h>

"#;

pub const SCRATCH_RUNTIME: &str = r#"// ====================================================
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

void* os_ScratchAlloc(size_t size) {
    // 8-byte alignment
    size = (size + 7) & ~7;
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

"#;

pub const ARENA_RUNTIME: &str = r#"// ====================================================
// GUST PRODUCTION-GRADE BUMP ALLOCATOR RUNTIME
// ====================================================
typedef struct {
    void* BaseAddress;
    size_t Offset;
    size_t Capacity;
} os_Arena;

os_Arena os_Arena_New() {
    os_Arena arena;
    arena.Capacity = 1024; // 1KB Initial Arena Capacity
    arena.BaseAddress = malloc(arena.Capacity);
    arena.Offset = 0;
    return arena;
}

void os_Arena_Free(os_Arena* arena) {
    if (arena->BaseAddress != NULL) {
        free(arena->BaseAddress);
        arena->BaseAddress = NULL;
    }
}

void std_GenerationalSwap(os_Arena* current, os_Arena* next) {
    os_Arena_Free(current);
    *current = *next;
    *next = os_Arena_New();
}

// Standard Hardware-aligned Bump Allocation [1]
int os_ArenaAlloc(os_Arena* arena, size_t size) {
    // Round up size to 8-byte boundary to satisfy hardware alignments [1]
    size = (size + 7) & ~7;
    if (arena->Offset + size > arena->Capacity) {
        arena->Capacity *= 2;
        arena->BaseAddress = realloc(arena->BaseAddress, arena->Capacity);
    }
    size_t assigned_offset = arena->Offset;
    arena->Offset += size;
    return (int)assigned_offset;
}

void os_LogInt(int val) {
    printf("%d\n", val);
}

typedef void* map_void_ptr;

"#;

pub const MOCK_PAYLOAD_RUNTIME: &str = r#"int os_argc = 0;
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

"#;

pub const FILE_IO_RUNTIME: &str = r#"// ====================================================
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

"#;

pub const COLLECTIONS_RUNTIME: &str = r#"// ====================================================
// GUST NATIVE COLLECTIONS RUNTIME (VECTOR & HASHMAP)
// ====================================================
static inline uint32_t os_hash_key(void* key_ptr, int is_str_key) {
    if (is_str_key) {
        Slice_unsigned_char s = *(Slice_unsigned_char*)key_ptr;
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
    while (m->occupied[idx]) {
        if (os_key_eq(m->keys + idx * key_size, key_ptr, is_str_key)) {
            return m->values + idx * val_size;
        }
        idx = (idx + 1) % m->capacity;
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
        __typeof__(*(map_ptr)->keys) _key = (key); \
        os_HashMapContains_impl((map_void_ptr)(map_ptr), &_key, (is_str_key), sizeof(*(map_ptr)->keys)); \
    })

#define os_HashMapRef(map_ptr, key, is_str_key) \
    ((__typeof__((map_ptr)->values))({ \
        __typeof__(*(map_ptr)->keys) _key = (key); \
        os_HashMapRef_impl((map_void_ptr)(map_ptr), &_key, (is_str_key), sizeof(*(map_ptr)->keys), sizeof(*(map_ptr)->values)); \
    }))

#define os_HashMapRemove(map_ptr, key, is_str_key) \
    do { \
        __typeof__(*(map_ptr)->keys) _key = (key); \
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
// GUST POSIX THREAD CONCURRENCY RUNTIME (MUTEX & CHANNEL)
// ====================================================
#define MAX_MUTEXES 1024
static pthread_mutex_t gust_mutex_pool[MAX_MUTEXES];
static int gust_mutex_count = 0;
static pthread_mutex_t gust_mutex_pool_lock = PTHREAD_MUTEX_INITIALIZER;

static inline int std_Mutex_Alloc() {
    pthread_mutex_lock(&gust_mutex_pool_lock);
    if (gust_mutex_count >= MAX_MUTEXES) {
        printf("Out of system mutexes!\n");
        exit(1);
    }
    int idx = gust_mutex_count++;
    pthread_mutex_init(&gust_mutex_pool[idx], NULL);
    pthread_mutex_unlock(&gust_mutex_pool_lock);
    return idx;
}

static inline void* std_Mutex_Lock_impl(int lock_state, void* value_ptr) {
    pthread_mutex_lock(&gust_mutex_pool[lock_state]);
    return value_ptr;
}

static inline void std_Mutex_Unlock_impl(int lock_state) {
    pthread_mutex_unlock(&gust_mutex_pool[lock_state]);
    sched_yield();
}

#define MAX_CHANNELS 256
typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t cond_recv;
    pthread_cond_t cond_send;
    char* data;
    int head;
    int tail;
    int count;
    int capacity;
    size_t elem_size;
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
    pthread_cond_init(&chan->cond_recv, NULL);
    pthread_cond_init(&chan->cond_send, NULL);
    chan->capacity = capacity > 0 ? capacity : 16;
    chan->elem_size = elem_size;
    chan->data = (char*)malloc(chan->capacity * elem_size);
    chan->head = 0;
    chan->tail = 0;
    chan->count = 0;
    pthread_mutex_unlock(&gust_channel_pool_lock);
    return idx;
}

static inline void std_Channel_Send_impl(int chan_idx, void* val_ptr) {
    gust_Channel_Internal* chan = &gust_channel_pool[chan_idx];
    pthread_mutex_lock(&chan->mutex);
    while (chan->count >= chan->capacity) {
        pthread_cond_wait(&chan->cond_send, &chan->mutex);
    }
    memcpy(chan->data + chan->tail * chan->elem_size, val_ptr, chan->elem_size);
    chan->tail = (chan->tail + 1) % chan->capacity;
    chan->count++;
    pthread_cond_signal(&chan->cond_recv);
    pthread_mutex_unlock(&chan->mutex);
}

static inline void std_Channel_Recv_impl(int chan_idx, void* out_ptr) {
    gust_Channel_Internal* chan = &gust_channel_pool[chan_idx];
    pthread_mutex_lock(&chan->mutex);
    while (chan->count <= 0) {
        pthread_cond_wait(&chan->cond_recv, &chan->mutex);
    }
    memcpy(out_ptr, chan->data + chan->head * chan->elem_size, chan->elem_size);
    chan->head = (chan->head + 1) % chan->capacity;
    chan->count--;
    pthread_cond_signal(&chan->cond_send);
    pthread_mutex_unlock(&chan->mutex);
}
"#;
