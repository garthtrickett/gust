#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif


// ====================================================
// GUST NATIVE COLLECTIONS RUNTIME (VECTOR & HASHMAP)
// ====================================================
void* os_HashMapRef_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size) {
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

int os_HashMapContains_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size) {
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

void os_HashMapRemove_impl(void* map_void, void* key_ptr, int is_str_key, size_t key_size, size_t val_size) {
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

void os_HashMapClear_impl(void* map_void, size_t key_size, size_t val_size) {
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

int std_PoolAlloc_impl(void* pool_void, size_t elem_size) {
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

void std_PoolFree_impl(void* pool_void, int index) {
    GenericPool* p = (GenericPool*)pool_void;
    if (index < 0 || index >= p->len) {
        printf("Pool index out of bounds on Free\n");
        exit(1);
    }
    p->occupied[index] = 0;
    p->free_list[p->free_len] = index;
    p->free_len++;
}
