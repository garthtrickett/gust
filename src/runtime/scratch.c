#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

#ifndef GUST_SCRATCH_SIZE
#define GUST_SCRATCH_SIZE 16384
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
