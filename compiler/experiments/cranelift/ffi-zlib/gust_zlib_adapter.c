#include "gust_zlib_adapter.h"

#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <zlib.h>

#if ZLIB_VERNUM != 0x1320
#error "The Phase 26 adapter requires the pinned zlib 1.3.2 headers"
#endif

enum {
    GUST_ZLIB_INVALID = -1,
    GUST_ZLIB_RANGE = -2,
    GUST_ZLIB_SHORT_OUTPUT = -3,
    GUST_ZLIB_CORRUPT = -4,
    GUST_ZLIB_ALLOCATION = -5,
    GUST_ZLIB_NATIVE = -6
};

/* This checks integer ranges without comparing unrelated C pointers. It does
 * not establish that a non-null address actually belongs to an allocation;
 * that remains the unsafe caller's obligation. Empty spans occupy no bytes. */
static int span_end(const void *pointer, int32_t count, uintptr_t *start,
                    uintptr_t *end) {
    if (count < 0 || (count != 0 && pointer == NULL)) {
        return GUST_ZLIB_INVALID;
    }
    *start = (uintptr_t)pointer;
    if ((uintptr_t)count > UINTPTR_MAX - *start) {
        return GUST_ZLIB_RANGE;
    }
    *end = *start + (uintptr_t)count;
    return 0;
}

static int validate_spans(const uint8_t *input, int32_t input_count,
                          uint8_t *destination, int32_t capacity) {
    uintptr_t input_start, input_end, output_start, output_end;
    int status = span_end(input, input_count, &input_start, &input_end);
    if (status != 0) {
        return status;
    }
    status = span_end(destination, capacity, &output_start, &output_end);
    if (status != 0) {
        return status;
    }
    if (input_count != 0 && capacity != 0 &&
        input_start < output_end && output_start < input_end) {
        return GUST_ZLIB_INVALID;
    }
    return 0;
}

static int32_t result_count(int status, uLongf count) {
    if (status == Z_OK) {
        return count <= INT32_MAX ? (int32_t)count : GUST_ZLIB_RANGE;
    }
    if (status == Z_BUF_ERROR) {
        return GUST_ZLIB_SHORT_OUTPUT;
    }
    if (status == Z_DATA_ERROR) {
        return GUST_ZLIB_CORRUPT;
    }
    if (status == Z_MEM_ERROR) {
        return GUST_ZLIB_ALLOCATION;
    }
    return GUST_ZLIB_NATIVE;
}

int32_t gust_zlib_bound(int32_t input_count) {
    if (input_count < 0) {
        return GUST_ZLIB_INVALID;
    }
    uLong bound = compressBound((uLong)input_count);
    return bound <= INT32_MAX ? (int32_t)bound : GUST_ZLIB_RANGE;
}

int32_t gust_zlib_compress(const uint8_t *input, int32_t input_count,
                          uint8_t *destination, int32_t capacity, int32_t level) {
    if (level < Z_DEFAULT_COMPRESSION || level > Z_BEST_COMPRESSION) {
        return GUST_ZLIB_INVALID;
    }
    int status = validate_spans(input, input_count, destination, capacity);
    if (status != 0) {
        return status;
    }
    const uint8_t input_dummy = 0;
    uint8_t output_dummy = 0;
    const Bytef *source = input_count == 0 ? &input_dummy : input;
    Bytef *output = capacity == 0 ? &output_dummy : destination;
    uLongf written = (uLongf)capacity;
    status = compress2(output, &written, source, (uLong)input_count, level);
    return result_count(status, written);
}

int32_t gust_zlib_decompress(const uint8_t *input, int32_t input_count,
                            uint8_t *destination, int32_t capacity) {
    int status = validate_spans(input, input_count, destination, capacity);
    if (status != 0) {
        return status;
    }
    const uint8_t input_dummy = 0;
    uint8_t output_dummy = 0;
    const Bytef *source = input_count == 0 ? &input_dummy : input;
    Bytef *output = capacity == 0 ? &output_dummy : destination;
    /* One private byte distinguishes a valid empty stream from a stream that
     * needs output even when the caller supplies zero capacity. */
    uLongf written = capacity == 0 ? 1 : (uLongf)capacity;
    status = uncompress(output, &written, source, (uLong)input_count);
    if (capacity == 0 && status == Z_OK && written != 0) {
        return GUST_ZLIB_SHORT_OUTPUT;
    }
    return result_count(status, written);
}
