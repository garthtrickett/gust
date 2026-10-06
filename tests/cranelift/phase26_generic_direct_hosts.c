#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef struct {
    uint8_t lead;
    uint8_t tail;
    int32_t tally;
} DirectAlpha;

typedef struct __attribute__((packed)) {
    int32_t count;
    uint8_t flag;
} DirectBeta;

_Static_assert(sizeof(DirectAlpha) == 8, "alpha C size");
_Static_assert(_Alignof(DirectAlpha) == 4, "alpha C alignment");
_Static_assert(offsetof(DirectAlpha, tally) == 4, "alpha C field order");
_Static_assert(sizeof(DirectBeta) == 5, "beta packed C size");
_Static_assert(_Alignof(DirectBeta) == 1, "beta packed C alignment");
_Static_assert(offsetof(DirectBeta, flag) == 4, "beta packed C field order");

int32_t host_direct_alpha(const DirectAlpha *read, DirectBeta *write,
                          int32_t bonus) {
    int32_t result = read->lead + read->tally + read->tail +
                     write->count + write->flag + bonus;
    write->count = 30 + bonus;
    write->flag = 7;
    puts("direct_alpha_host");
    fflush(stdout);
    return result;
}

int32_t host_direct_beta(const DirectBeta *read, DirectAlpha *write,
                         int32_t bonus) {
    int32_t result = read->count + read->flag +
                     write->lead + write->tally + write->tail + bonus;
    write->tally = 41;
    write->tail = 9;
    puts("direct_beta_host");
    fflush(stdout);
    return result;
}
