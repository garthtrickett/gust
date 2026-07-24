#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

int32_t tiny_host_add_one_i32(int32_t value) {
    return value + 1;
}

int32_t tiny_host_add_i32(int32_t left, int32_t right) {
    return left + right;
}

int32_t tiny_host_is_positive_i32(int32_t value) {
    return value > 0 ? 1 : 0;
}
