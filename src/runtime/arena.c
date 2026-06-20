#include "core_headers.h"

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

// Standard Hardware-aligned Bump Allocation
int os_ArenaAlloc(os_Arena* arena, size_t size) {
    // Round up size to 8-byte boundary to satisfy hardware alignments
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
