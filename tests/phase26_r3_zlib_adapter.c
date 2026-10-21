#include "gust_zlib_adapter.h"

#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static int failures;

#define CHECK(condition) do { \
    if (!(condition)) { \
        fprintf(stderr, "R3 adapter check failed at line %d: %s\n", \
                __LINE__, #condition); \
        failures++; \
    } \
} while (0)

int main(void) {
    uint8_t plain[4096];
    uint32_t state = 0x5a17c3e2u;
    for (size_t i = 0; i < sizeof plain; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        plain[i] = (uint8_t)state;
    }
    uint8_t compressed[8192] = {0};
    uint8_t restored[4096] = {0};
    int32_t bound = gust_zlib_bound((int32_t)sizeof plain);
    CHECK(gust_zlib_bound(0) == 13);
    CHECK(gust_zlib_bound(2) == 15);
    CHECK(bound >= (int32_t)sizeof plain);
    CHECK(bound <= (int32_t)sizeof compressed);
    int32_t count = gust_zlib_compress(plain, (int32_t)sizeof plain,
                                       compressed, (int32_t)sizeof compressed, 6);
    CHECK(count > (int32_t)sizeof plain && count <= bound);
    int32_t restored_count = gust_zlib_decompress(compressed, count,
                                                  restored, (int32_t)sizeof restored);
    CHECK(restored_count == (int32_t)sizeof plain);
    CHECK(memcmp(plain, restored, sizeof plain) == 0);

    uint8_t empty_stream[64] = {0};
    int32_t empty_count = gust_zlib_compress(NULL, 0, empty_stream,
                                             (int32_t)sizeof empty_stream, -1);
    static const uint8_t known_empty[] = {0x78, 0x9c, 0x03, 0x00,
                                           0x00, 0x00, 0x00, 0x01};
    static const uint8_t known_two[] = {0x78, 0x9c, 0x63, 0x66, 0x01,
                                         0x00, 0x00, 0x0c, 0x00, 0x08};
    CHECK(empty_count == (int32_t)sizeof known_empty);
    CHECK(memcmp(empty_stream, known_empty, sizeof known_empty) == 0);
    CHECK(gust_zlib_compress((const uint8_t *)"\x03\x04", 2,
                              compressed, (int32_t)sizeof compressed, 6) ==
          (int32_t)sizeof known_two);
    CHECK(memcmp(compressed, known_two, sizeof known_two) == 0);
    CHECK(gust_zlib_decompress(empty_stream, empty_count, NULL, 0) == 0);
    CHECK(gust_zlib_decompress(compressed, count, NULL, 0) == -3);
    CHECK(gust_zlib_decompress(compressed, count, restored, 1) == -3);
    CHECK(gust_zlib_compress(plain, (int32_t)sizeof plain, NULL, 0, 6) == -3);

    uint8_t corrupt[8192];
    memcpy(corrupt, compressed, (size_t)count);
    corrupt[0] ^= 0xff;
    CHECK(gust_zlib_decompress(corrupt, count, restored,
                                (int32_t)sizeof restored) == -4);
    CHECK(gust_zlib_bound(-1) == -1);
    CHECK(gust_zlib_bound(INT32_MAX) == -2);
    CHECK(gust_zlib_compress(NULL, 1, compressed, 8, 6) == -1);
    CHECK(gust_zlib_compress(plain, 8, compressed, -1, 6) == -1);
    CHECK(gust_zlib_decompress(NULL, 1, restored, 8) == -1);
    CHECK(gust_zlib_compress(plain, 8, NULL, 8, 6) == -1);
    CHECK(gust_zlib_compress(plain, 8, compressed, 8, -2) == -1);
    CHECK(gust_zlib_compress(plain, 8, compressed, 8, 10) == -1);
    CHECK(gust_zlib_compress(plain, 8, plain + 1, 8, 6) == -1);
    CHECK(gust_zlib_decompress(plain, 8, plain + 1, 8) == -1);
    CHECK(gust_zlib_compress((const uint8_t *)(UINTPTR_MAX - 1u), 4,
                              compressed, 8, 6) == -2);
    CHECK(gust_zlib_decompress(compressed, 8,
                                (uint8_t *)(UINTPTR_MAX - 1u), 4) == -2);

    if (failures != 0) {
        return 1;
    }
    puts("phase26_r3_zlib_adapter: PASS");
    return 0;
}
