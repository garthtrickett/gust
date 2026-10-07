#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct { int32_t *raw; } LeaseInt;
typedef struct { uint8_t *raw; } LeaseByte;

_Static_assert(sizeof(LeaseInt) == sizeof(void *), "LeaseInt pointer ABI");
_Static_assert(_Alignof(LeaseInt) == _Alignof(void *), "LeaseInt alignment");
_Static_assert(sizeof(LeaseByte) == sizeof(void *), "LeaseByte pointer ABI");
_Static_assert(_Alignof(LeaseByte) == _Alignof(void *), "LeaseByte alignment");

static int32_t *retained_int;
static uint8_t *retained_byte;

LeaseInt host_make_lease_int(int32_t value) {
    LeaseInt result = { .raw = malloc(sizeof(int32_t)) };
    if (!result.raw) abort();
    *result.raw = value;
    return result;
}

void host_register_lease_int(int32_t *raw, int32_t marker) {
    if (!raw || retained_int || marker != 1 || *raw != 41) abort();
    retained_int = raw;
    puts("registered_int");
    fflush(stdout);
}

void host_check_lease_int(int32_t marker) {
    if (marker != 1 || !retained_int || *retained_int != 41) abort();
    puts("checked_int");
    fflush(stdout);
}

void host_free_lease_int(int32_t *raw) {
    if (!raw || raw != retained_int) abort();
    if (*retained_int != 41) abort();
    puts("retained_int_read");
    fflush(stdout);
    retained_int = NULL;
    puts("unregistered_int");
    fflush(stdout);
    free(raw);
    puts("freed_int");
    fflush(stdout);
}

LeaseByte host_make_lease_byte(void) {
    LeaseByte result = { .raw = malloc(sizeof(uint8_t)) };
    if (!result.raw) abort();
    *result.raw = 42;
    return result;
}

void host_register_lease_byte(int32_t marker, uint8_t *raw) {
    if (!raw || retained_byte || marker != 2 || *raw != 42) abort();
    retained_byte = raw;
    puts("registered_byte");
    fflush(stdout);
}

void host_check_lease_byte(int32_t marker) {
    if (marker != 2 || !retained_byte || *retained_byte != 42) abort();
    puts("checked_byte");
    fflush(stdout);
}

void host_free_lease_byte(uint8_t *raw) {
    if (!raw || raw != retained_byte) abort();
    if (*retained_byte != 42) abort();
    puts("retained_byte_read");
    fflush(stdout);
    retained_byte = NULL;
    puts("unregistered_byte");
    fflush(stdout);
    free(raw);
    puts("freed_byte");
    fflush(stdout);
}
