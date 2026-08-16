#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

// ====================================================
// GUST HOST I/O AND PROCESS PRIMITIVES
// ====================================================
// Process arguments and standard-stream logging are host platform primitives.
// They have no pure Gust equivalent and are expected to remain retained C.

// Process argv storage, populated by main(). Owned here because os_Args and
// os_ExecutablePath are the only readers.
int os_argc = 0;
char** os_argv = NULL;

struct std_Vector_str os_Args(os_Arena* ctx) {
    struct std_Vector_str vec = (struct std_Vector_str){ .data = NULL, .len = 0, .capacity = 0, .arena = ctx };
    for (int i = 0; i < os_argc; i++) {
        int len = strlen(os_argv[i]);
        int offset = os_ArenaAlloc(ctx, len);
        char* data = (char*)ctx->BaseAddress + GUST_ARENA_OFFSET(offset);
        memcpy(data, os_argv[i], len);
        Slice_unsigned_char s = (Slice_unsigned_char){ (unsigned char*)data, len };

        if (vec.len >= vec.capacity) {
                int new_cap = vec.capacity == 0 ? 8 : vec.capacity * 2;
                int alloc_offset = os_ArenaAlloc(ctx, new_cap * sizeof(Slice_unsigned_char));
                Slice_unsigned_char* new_data = (Slice_unsigned_char*)((char*)ctx->BaseAddress + GUST_ARENA_OFFSET(alloc_offset));
                if (vec.data != NULL && vec.len > 0) {
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

void os_LogError(Slice_unsigned_char s) {
    fprintf(stderr, "%.*s", s.len, (char*)s.data);
    if (s.len == 0 || s.data[s.len - 1] != '\n') {
        fputc('\n', stderr);
    }
    fflush(stderr);
}
