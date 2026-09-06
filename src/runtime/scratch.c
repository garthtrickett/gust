#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

#ifndef GUST_SCRATCH_SIZE
#define GUST_SCRATCH_SIZE 131072
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

// Scratch gets its own arena rather than the caller's.
//
// RELOCATION IS NOT RECLAMATION. Nothing is reset here and no lifetime changes:
// with no reset, scratch memory stays valid for the whole process exactly as it
// does today, Cloned or not. Every pointer valid before this change is valid
// after it. That is what makes this safe - it has no lifetime semantics at all.
//
// Why: os_ScratchAlloc took `active_thread_arena`, which programs set to their
// OWN arena (compiler/test_runner_entry.gst:244 does
// `os.SetThreadScratch(ctx)`), so every std.Concat and every int-to-string in
// compiled Gust permanently consumed the program's main arena. Measured while
// self-compiling the compiler: 1.98 GB across 15.8 million allocations, 46% of
// a 4 GB arena that was 99.84% full with 9,584 bytes to spare. std.Clone copies
// scratch into the permanent arena precisely because scratch is meant to be
// transient; only the reclaiming half was never implemented.
//
// `active_thread_arena != NULL` is retained as the program's OPT-IN to
// arena-backed scratch rather than the 128KB thread-local buffer. Only the
// arena it lands in changes.
//
// SHARING, for whoever adds the reset later: `active_thread_arena` is saved and
// restored per fiber switch, so each fiber used to scratch into its own arena.
// This scratch arena is thread-local, so ALL FIBERS ON A THREAD NOW SHARE ONE
// SCRATCH ARENA. With no reset that is safe - merely shared. A future reset
// must account for it: rewinding this arena affects every fiber on the thread,
// not just the one that called. That is the trap the reset has to avoid.
static GUST_THREAD_LOCAL os_Arena  os_scratch_arena;
static GUST_THREAD_LOCAL os_Arena* os_scratch_arena_ptr = NULL;

void* os_ScratchAlloc(size_t size) {
    // 8-byte alignment
    size = (size + 7) & ~7;
    if (active_thread_arena != NULL) {
        if (os_scratch_arena_ptr == NULL) {
            os_scratch_arena = os_Arena_New();
            os_scratch_arena_ptr = &os_scratch_arena;
        }
        int offset = os_ArenaAlloc(os_scratch_arena_ptr, size);
        return (char*)os_scratch_arena_ptr->BaseAddress + GUST_ARENA_OFFSET(offset);
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
