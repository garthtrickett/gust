#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// ====================================================
// GUST MINIMAL C RUNTIME DEFINITIONS
// ====================================================
typedef struct {
    void* BaseAddress;
} os_Arena;

os_Arena os_Arena_New() {
    os_Arena arena;
    arena.BaseAddress = malloc(1024); // Allocate mock arena heap block
    return arena;
}

void os_Arena_Free(os_Arena* arena) {
    if (arena->BaseAddress != NULL) {
        free(arena->BaseAddress);
        arena->BaseAddress = NULL;
    }
}

static int alloc_counter = 0;
int os_ArenaAlloc(os_Arena* arena) {
    int assigned = alloc_counter;
    alloc_counter++;
    return assigned;
}

void os_LogInt(int val) {
    printf("%d\n", val);
}

typedef struct {
    int SessionID;
    int Next;
} SessionNode;

typedef struct {
    int UserID;
    unsigned char UserTag[16];
    int Active;
} APIRequest;

typedef struct {
    APIRequest* Val;
    int Ok;
} CastResult;

unsigned char* os_MockPayload() {
    unsigned char* buf = malloc(sizeof(APIRequest));
    ((APIRequest*)buf)->UserID = 42;
    return buf;
}

// ====================================================
// TRANSPILED PROGRAM CODES
// ====================================================
int main() {
    unsigned char* payload = os_MockPayload();
    CastResult result = ({ CastResult res; res.Ok = (((uintptr_t)payload & 7) == 0); res.Val = (APIRequest*)payload; res; });
    result.Ok;
    os_LogInt(result.Val->UserID);
    return 0;
}
