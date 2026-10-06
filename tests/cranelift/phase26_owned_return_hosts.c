#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct { int32_t *raw; } OwnedInt;
typedef struct { uint8_t *raw; } OwnedByte;

_Static_assert(sizeof(OwnedInt) == sizeof(void *), "OwnedInt must be one pointer");
_Static_assert(_Alignof(OwnedInt) == _Alignof(void *), "OwnedInt alignment");
_Static_assert(sizeof(OwnedByte) == sizeof(void *), "OwnedByte must be one pointer");
_Static_assert(_Alignof(OwnedByte) == _Alignof(void *), "OwnedByte alignment");

OwnedInt host_owned_int(int32_t value) {
    OwnedInt owner = { .raw = malloc(sizeof(int32_t)) };
    if (!owner.raw) abort();
    *owner.raw = value;
    return owner;
}

void host_release_owned_int(int32_t *raw) {
    if (!raw) abort();
    free(raw);
    puts("released_int");
    fflush(stdout);
}

OwnedByte host_owned_byte(void) {
    OwnedByte owner = { .raw = malloc(sizeof(uint8_t)) };
    if (!owner.raw) abort();
    *owner.raw = 7;
    return owner;
}

void host_release_owned_byte(uint8_t *raw) {
    if (!raw) abort();
    free(raw);
    puts("released_byte");
    fflush(stdout);
}
