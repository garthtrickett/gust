#include <stdint.h>
#include <limits.h>

int32_t host_status_alpha(int32_t selector) {
    switch (selector) {
    case 0: return 0;
    case 1: return 17;
    case 2: return -23;
    case 3: return INT32_MAX;
    case 4: return INT32_MIN;
    default: return -1;
    }
}

int32_t host_status_beta(int32_t selector) {
    if (selector == 0) return 0;
    if (selector == 1) return 31;
    if (selector == 2) return -41;
    if (selector == 3) return INT32_MAX;
    return INT32_MIN;
}

int32_t host_status_zero_arg(void) {
    return INT32_MIN;
}
