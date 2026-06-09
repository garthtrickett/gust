#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// ====================================================
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

// ====================================================
// FORWARD DECLARATIONS
// ====================================================
typedef struct Client_ctx Client_ctx;
typedef struct SessionNode SessionNode;
typedef struct APIRequest APIRequest;
typedef struct Client_clientCtx Client_clientCtx;

// ====================================================
// DYNAMICALLY GENERATED SLICE STRUCTURES
// ====================================================
typedef struct {
    unsigned char* data;
    int len;
} Slice_unsigned_char;

Slice_unsigned_char os_MockPayload() {
    Slice_unsigned_char slice;
    slice.data = malloc(1024);
    slice.len = 1024;
    ((int*)slice.data)[0] = 42;
    return slice;
}

void os_LogStr(Slice_unsigned_char s) {
    printf("%.*s\n", s.len, (char*)s.data);
}

// ====================================================
// DYNAMICALLY TRANSPILED USER STRUCTS
// ====================================================
struct Client_ctx {
    int ClientID;
    int Balance;
};

typedef struct {
    Client_ctx* Val;
    int Ok;
} CastResult_Client_ctx;

struct SessionNode {
    int SessionID;
    int Next;
};

typedef struct {
    SessionNode* Val;
    int Ok;
} CastResult_SessionNode;

struct APIRequest {
    int Active;
    int UserID;
    int SessionID;
};

typedef struct {
    APIRequest* Val;
    int Ok;
} CastResult_APIRequest;

struct Client_clientCtx {
    int ClientID;
    int Balance;
};

typedef struct {
    Client_clientCtx* Val;
    int Ok;
} CastResult_Client_clientCtx;

// ====================================================
// TRANSPILED PROGRAM CODES
// ====================================================
void chargeClient(os_Arena* ctx, int c, int amount) {
    (( Client_ctx*)((char*)ctx->BaseAddress + c))->Balance = (( Client_ctx*)((char*)ctx->BaseAddress + c))->Balance - amount;
}

int main() {
    os_Arena clientCtx = os_Arena_New();
    int user = os_ArenaAlloc(&clientCtx, sizeof(Client_clientCtx));
    (( Client_clientCtx*)((char*)clientCtx.BaseAddress + user))->ClientID = 101;
    (( Client_clientCtx*)((char*)clientCtx.BaseAddress + user))->Balance = 500;
    chargeClient(&clientCtx, user, 75);
    Slice_unsigned_char prefix = (Slice_unsigned_char){ (unsigned char*)"Client balance remaining:", 25 };
    os_LogStr(prefix);
    os_LogInt((( Client_clientCtx*)((char*)clientCtx.BaseAddress + user))->Balance);
    // === DEFERRED CLEANUP CODES ===
    os_Arena_Free(&clientCtx);
    return 0;
}

