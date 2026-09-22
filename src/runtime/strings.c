/* GENERATED FILE -- DO NOT EDIT.
 *
 * Emitted from compiler/runtime/strings.gst by
 * scripts/phase25_runtime_strings_generated.sh --write.
 *
 * Patch 25.5 moved the nine pure functions of the C string runtime
 * to Gust. This file is what the compiler makes of them, kept at
 * the path the hand-written original had so that src/runtime.c,
 * the phase21 archive member list and the registry rows all keep
 * naming strings.o. Editing it here is lost on the next
 * regeneration; edit the Gust and re-run the script.
 *
 * std_Clone_str and std_str_split are NOT here. Both need N raw
 * bytes from a caller-supplied arena, which Gust cannot express,
 * and they live in src/runtime-rs under D2's per-file fallback.
 */
#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif
// Transpiled C Code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

typedef void Any;

/* Builtin slice structs are runtime-owned in src/runtime/core_headers.h. */

// Forward Declarations
typedef struct APIRequest APIRequest;
typedef struct SessionNode SessionNode;
typedef struct StrHeader StrHeader;
typedef struct CastResult_APIRequest CastResult_APIRequest;
typedef struct CastResult_SessionNode CastResult_SessionNode;
typedef struct CastResult_StrHeader CastResult_StrHeader;

// Function Forward Declarations
int StrHeader_IsValid(StrHeader* req);
os_Arena os_Arena_New(void);
void os_SetThreadScratch(os_Arena* arg0);
int os_System(Slice_unsigned_char arg0);
os_Arena os_Arena_New(void);
os_Arena os_Arena_New(void);
void os_SetThreadScratch(os_Arena* arg0);
int os_System(Slice_unsigned_char arg0);
void std_Yield(void);
void std_Yield(void);
void std_str_bounds_fail(Slice_unsigned_char what);

// Structures
#ifndef GUST_STRUCT_StrHeader_DEFINED
#define GUST_STRUCT_StrHeader_DEFINED
struct StrHeader {
    unsigned char* data;
    int len;
};
#endif

// pthread_wrapper forward declarations
void* std_is_alpha_pthread_wrapper(void* arg);
void* std_is_digit_pthread_wrapper(void* arg);
void* std_is_whitespace_pthread_wrapper(void* arg);
void* std_str_bounds_fail_pthread_wrapper(void* arg);
void* std_parse_int_pthread_wrapper(void* arg);
void* std_str_trim_pthread_wrapper(void* arg);

// Invariant Validator forward declarations
int StrHeader_IsValid(StrHeader* req);

// Invariant Validator implementations
int StrHeader_IsValid(StrHeader* req) {
    if (req == NULL) return 0;
    return 1;
}

// Program Statements
int std_str_eq(Slice_unsigned_char s1, Slice_unsigned_char s2) {
    if ((s1.len != s2.len)) {
    return 0;
    }
    int i = 0;
    while ((i < s1.len)) {
        gust_tick();
    if (((*({ if (i < 0 || i >= s1.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s1.data[i]); })) != (*({ if (i < 0 || i >= s2.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s2.data[i]); })))) {
    return 0;
    }
    i = (i + 1);
    }
    return 1;
}

unsigned char std_str_byte_at(Slice_unsigned_char s, int idx) {
    if ((idx < 0)) {
    std_str_bounds_fail(((Slice_unsigned_char){ (unsigned char*)"std.str_byte_at bounds check failed", 35 }));
    }
    if ((idx >= s.len)) {
    std_str_bounds_fail(((Slice_unsigned_char){ (unsigned char*)"std.str_byte_at bounds check failed", 35 }));
    }
    return (*({ if (idx < 0 || idx >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[idx]); }));
}

unsigned char std_is_alpha(unsigned char b) {
    if ((b >= 97)) {
    if ((b <= 122)) {
    return 1;
    }
    }
    if ((b >= 65)) {
    if ((b <= 90)) {
    return 1;
    }
    }
    if ((b == 95)) {
    return 1;
    }
    return 0;
}

void* std_is_alpha_pthread_wrapper(void* arg) {
    std_is_alpha((unsigned char)(uintptr_t)arg);
    return NULL;
}

unsigned char std_is_digit(unsigned char b) {
    if ((b >= 48)) {
    if ((b <= 57)) {
    return 1;
    }
    }
    return 0;
}

void* std_is_digit_pthread_wrapper(void* arg) {
    std_is_digit((unsigned char)(uintptr_t)arg);
    return NULL;
}

unsigned char std_is_whitespace(unsigned char b) {
    if ((b == 32)) {
    return 1;
    }
    if ((b == 9)) {
    return 1;
    }
    if ((b == 10)) {
    return 1;
    }
    if ((b == 13)) {
    return 1;
    }
    return 0;
}

void* std_is_whitespace_pthread_wrapper(void* arg) {
    std_is_whitespace((unsigned char)(uintptr_t)arg);
    return NULL;
}

int std_str_find(Slice_unsigned_char s, Slice_unsigned_char target) {
    if ((target.len == 0)) {
    return 0;
    }
    if ((s.len < target.len)) {
    return (0 - 1);
    }
    int i = 0;
    while ((i <= (s.len - target.len))) {
        gust_tick();
    int j = 0;
    int hit = 1;
    while ((j < target.len)) {
        gust_tick();
    if (((*({ if ((i + j) < 0 || (i + j) >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[(i + j)]); })) != (*({ if (j < 0 || j >= target.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(target.data[j]); })))) {
    hit = 0;
    j = target.len;
    } else {
    j = (j + 1);
    }
    }
    if ((hit == 1)) {
    return i;
    }
    i = (i + 1);
    }
    return (0 - 1);
}

void std_str_bounds_fail(Slice_unsigned_char what) {
    os_LogStr(what);
    exit(1);
}

void* std_str_bounds_fail_pthread_wrapper(void* arg) {
    std_str_bounds_fail(*(Slice_unsigned_char*)arg);
    return NULL;
}

Slice_unsigned_char std_str_slice(Slice_unsigned_char s, int start, int end) {
    if ((start < 0)) {
    std_str_bounds_fail(((Slice_unsigned_char){ (unsigned char*)"std.str_slice bounds check failed", 33 }));
    }
    if ((end < start)) {
    std_str_bounds_fail(((Slice_unsigned_char){ (unsigned char*)"std.str_slice bounds check failed", 33 }));
    }
    if ((end > s.len)) {
    std_str_bounds_fail(((Slice_unsigned_char){ (unsigned char*)"std.str_slice bounds check failed", 33 }));
    }
    StrHeader hdr = ((StrHeader){ .data = NULL, .len = 0 });
    {
    StrHeader* sp = ((StrHeader*)&(s));
    hdr.data = ((*(sp)).data + start);
    hdr.len = (end - start);
    StrHeader* hp = ((StrHeader*)&(hdr));
    return (*(((Slice_unsigned_char*)(((Slice_unsigned_char*)hp) + 0))));
    }
}

int std_parse_int(Slice_unsigned_char s) {
    if ((s.len <= 0)) {
    return 0;
    }
    int index = 0;
    int sign = 1;
    unsigned char c0 = (*({ if (0 < 0 || 0 >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[0]); }));
    if ((c0 == 45)) {
    sign = (0 - 1);
    index = 1;
    } else {
    if ((c0 == 43)) {
    index = 1;
    }
    }
    int result = 0;
    int go = 1;
    while ((go == 1)) {
        gust_tick();
    if ((index >= s.len)) {
    go = 0;
    } else {
    unsigned char c = (*({ if (index < 0 || index >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[index]); }));
    if ((c >= 48)) {
    if ((c <= 57)) {
    result = ((result * 10) + (c - 48));
    index = (index + 1);
    } else {
    go = 0;
    }
    } else {
    go = 0;
    }
    }
    }
    return (result * sign);
}

void* std_parse_int_pthread_wrapper(void* arg) {
    std_parse_int(*(Slice_unsigned_char*)arg);
    return NULL;
}

Slice_unsigned_char std_str_trim(Slice_unsigned_char s) {
    int start = 0;
    int go = 1;
    while ((go == 1)) {
        gust_tick();
    if ((start >= s.len)) {
    go = 0;
    } else {
    unsigned char c = (*({ if (start < 0 || start >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[start]); }));
    if ((c == 32)) {
    start = (start + 1);
    } else {
    if ((c == 9)) {
    start = (start + 1);
    } else {
    if ((c == 10)) {
    start = (start + 1);
    } else {
    if ((c == 13)) {
    start = (start + 1);
    } else {
    go = 0;
    }
    }
    }
    }
    }
    }
    int e = s.len;
    int go2 = 1;
    while ((go2 == 1)) {
        gust_tick();
    if ((e <= start)) {
    go2 = 0;
    } else {
    unsigned char c2 = (*({ if ((e - 1) < 0 || (e - 1) >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[(e - 1)]); }));
    if ((c2 == 32)) {
    e = (e - 1);
    } else {
    if ((c2 == 9)) {
    e = (e - 1);
    } else {
    if ((c2 == 10)) {
    e = (e - 1);
    } else {
    if ((c2 == 13)) {
    e = (e - 1);
    } else {
    go2 = 0;
    }
    }
    }
    }
    }
    }
    return std_str_slice(s, start, e);
}

void* std_str_trim_pthread_wrapper(void* arg) {
    std_str_trim(*(Slice_unsigned_char*)arg);
    return NULL;
}


