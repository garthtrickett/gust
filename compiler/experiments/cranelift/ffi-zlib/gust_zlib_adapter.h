#ifndef GUST_ZLIB_ADAPTER_H
#define GUST_ZLIB_ADAPTER_H

#include <stdint.h>

/* The Phase 26 first-release native interface. A nonnegative result is the
 * number of initialized destination bytes. Errors never publish that count.
 * Pointers are borrowed only for the duration of a call. */
int32_t gust_zlib_bound(int32_t input_count);
int32_t gust_zlib_compress(const uint8_t *input, int32_t input_count,
                          uint8_t *destination, int32_t capacity, int32_t level);
int32_t gust_zlib_decompress(const uint8_t *input, int32_t input_count,
                            uint8_t *destination, int32_t capacity);

#endif
