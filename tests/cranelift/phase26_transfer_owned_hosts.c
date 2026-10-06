#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct { int32_t *raw; } OwnedInt;
typedef struct { uint8_t *raw; } OwnedByte;

_Static_assert(sizeof(OwnedInt) == sizeof(void *), "OwnedInt must be one pointer");
_Static_assert(_Alignof(OwnedInt) == _Alignof(void *), "OwnedInt alignment");
_Static_assert(sizeof(OwnedByte) == sizeof(void *), "OwnedByte must be one pointer");
_Static_assert(_Alignof(OwnedByte) == _Alignof(void *), "OwnedByte alignment");

static int int_acquired;
static int int_released;
static int byte_acquired;
static int byte_released;
static int check_registered;

static void host_check_owned_counts(void) {
    if (int_acquired != 2 || int_released != 2 ||
        byte_acquired != 1 || byte_released != 1) abort();
    printf("counts:%d:%d:%d:%d\n", int_acquired, int_released,
           byte_acquired, byte_released);
    fflush(stdout);
}

static void register_check(void) {
    if (!check_registered) {
        if (atexit(host_check_owned_counts) != 0) abort();
        check_registered = 1;
    }
}

OwnedInt host_owned_int(int32_t value) {
    register_check();
    OwnedInt owner = { .raw = malloc(sizeof(int32_t)) };
    if (!owner.raw) abort();
    *owner.raw = value;
    ++int_acquired;
    return owner;
}

void host_release_owned_int(int32_t *raw) {
    if (!raw || int_released >= int_acquired) abort();
    ++int_released;
    free(raw);
    puts("released_int");
    fflush(stdout);
}

void host_take_owned_int(OwnedInt owner) {
    if (!owner.raw) abort();
    printf("taken_int:%d\n", *owner.raw);
    host_release_owned_int(owner.raw);
}

OwnedByte host_owned_byte(void) {
    register_check();
    OwnedByte owner = { .raw = malloc(sizeof(uint8_t)) };
    if (!owner.raw) abort();
    *owner.raw = 7;
    ++byte_acquired;
    return owner;
}

void host_release_owned_byte(uint8_t *raw) {
    if (!raw || byte_released >= byte_acquired) abort();
    ++byte_released;
    free(raw);
    puts("released_byte");
    fflush(stdout);
}

void host_take_owned_byte(OwnedByte owner) {
    if (!owner.raw) abort();
    printf("taken_byte:%u\n", (unsigned)*owner.raw);
    host_release_owned_byte(owner.raw);
}
