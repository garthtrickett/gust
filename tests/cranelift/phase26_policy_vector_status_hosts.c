#include <stdint.h>
#include <stdbool.h>

struct vector_alpha {
    int32_t amount;
    uint8_t flag;
};

struct __attribute__((packed)) vector_beta {
    int32_t amount;
    uint8_t marker;
};

static int32_t alpha_status(int32_t selector) {
    static const int32_t result[] = {0, 17, -23, INT32_MIN, INT32_MAX};
    return selector >= 0 && selector < 5 ? result[selector] : -1;
}

static int32_t beta_status(int32_t selector) {
    static const int32_t result[] = {0, 31, -41, INT32_MIN, INT32_MAX};
    return selector >= 0 && selector < 5 ? result[selector] : -1;
}

int32_t host_vector_alpha(const struct vector_alpha *direct_read,
                          const struct vector_beta *isolated_read,
                          struct vector_alpha *direct_write,
                          struct vector_beta *isolated_write,
                          int32_t selector) {
    if (direct_read->amount != 10 || direct_read->flag != 2 ||
        isolated_read->amount != 5 || isolated_read->marker != 3)
        return -999;
    direct_write->amount = 100 + selector;
    direct_write->flag = 7;
    isolated_write->amount = 200 + selector;
    isolated_write->marker = 8;
    return alpha_status(selector);
}

int32_t host_vector_beta(const struct vector_beta *direct_read,
                         const struct vector_alpha *isolated_read,
                         struct vector_beta *direct_write,
                         struct vector_alpha *isolated_write,
                         int32_t selector) {
    if (direct_read->amount != 5 || direct_read->marker != 3 ||
        isolated_read->amount != 10 || isolated_read->flag != 2)
        return -998;
    direct_write->amount = 300 + selector;
    direct_write->marker = 9;
    isolated_write->amount = 400 + selector;
    isolated_write->flag = 10;
    return beta_status(selector);
}

int32_t host_vector_alias_pair(const struct vector_alpha *direct_read,
                               const struct vector_alpha *isolated_read) {
    return direct_read->amount == 10 && isolated_read->amount == 104 &&
        direct_read != isolated_read ? 0 : -997;
}

int32_t host_vector_scalar_mix(const struct vector_alpha *direct_read,
                               const struct vector_alpha *isolated_read,
                               uint8_t byte_value, bool bool_value) {
    return direct_read->amount == 10 && isolated_read->amount == 104 &&
        byte_value == 7 && bool_value ? 0 : -996;
}
