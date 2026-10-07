#include <stdint.h>
#include <stdio.h>

int32_t host_apply_alpha(int32_t (*callback)(int32_t), int32_t bias) {
    puts("callback_alpha_host");
    fflush(stdout);
    return callback(7) + bias;
}

int32_t host_apply_beta(int32_t bias, int32_t (*callback)(int32_t),
                        int32_t scale) {
    puts("callback_beta_host");
    fflush(stdout);
    return callback(bias) * scale;
}
