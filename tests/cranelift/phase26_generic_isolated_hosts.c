#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef struct {
    uint8_t lead;
    uint8_t tail;
    int32_t tally;
} IsolatedAlpha;

typedef struct __attribute__((packed)) {
    int32_t count;
    uint8_t flag;
} IsolatedBeta;

_Static_assert(sizeof(IsolatedAlpha) == 8, "alpha C size");
_Static_assert(_Alignof(IsolatedAlpha) == 4, "alpha C alignment");
_Static_assert(offsetof(IsolatedAlpha, tally) == 4, "alpha C field order");
_Static_assert(sizeof(IsolatedBeta) == 5, "beta packed C size");
_Static_assert(_Alignof(IsolatedBeta) == 1, "beta packed C alignment");
_Static_assert(offsetof(IsolatedBeta, flag) == 4, "beta packed C field order");

int32_t host_isolated_alpha(const IsolatedAlpha *read, IsolatedBeta *write,
                            int32_t bonus) {
    int32_t result = read->lead + read->tally + read->tail +
                     write->count + write->flag + bonus;
    /* The read policy must isolate even a native host that writes through it. */
    ((uint8_t *)(void *)read)[0] = 99;
    write->count = 30 + bonus;
    write->flag = 7;
    puts("alpha_host");
    fflush(stdout);
    return result;
}

int32_t host_isolated_beta(const IsolatedBeta *read, IsolatedAlpha *write,
                           int32_t bonus) {
    int32_t result = read->count + read->flag +
                     write->lead + write->tally + write->tail + bonus;
    ((uint8_t *)(void *)read)[4] = 55;
    write->tally = 41;
    write->tail = 9;
    puts("beta_host");
    fflush(stdout);
    return result;
}
