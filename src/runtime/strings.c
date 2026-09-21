#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

// ====================================================
// GUST STRING AND CHARACTER STANDARD LIBRARY
// ====================================================
// Pure algorithms over slices and bytes. No irreducible host dependency, so
// these are the natural candidates for migration to pure Gust modules.
int std_str_eq(Slice_unsigned_char s1, Slice_unsigned_char s2) {
 if (s1.len != s2.len) return 0;
 if (s1.len == 0) return 1;
 return memcmp(s1.data, s2.data, s1.len) == 0;
}

Slice_unsigned_char std_str_slice(Slice_unsigned_char s, int start, int end) {
    Slice_unsigned_char res;
    if (start < 0 || end < start || end > s.len) {
        printf("std.str_slice bounds check failed\n");
        exit(1);
    }
    res.data = s.data + start;
    res.len = end - start;
    return res;
}

unsigned char std_str_byte_at(Slice_unsigned_char s, int idx) {
    if (idx < 0 || idx >= s.len) {
        printf("std.str_byte_at bounds check failed\n");
        exit(1);
    }
    return s.data[idx];
}

int std_str_find(Slice_unsigned_char s, Slice_unsigned_char target) {
    if (target.len == 0) return 0;
    if (s.len < target.len) return -1;
    for (int i = 0; i <= s.len - target.len; i++) {
        if (memcmp(s.data + i, target.data, target.len) == 0) {
            return i;
        }
    }
    return -1;
}

Slice_unsigned_char std_str_trim(Slice_unsigned_char s) {
    int start = 0;
    while (start < s.len && (s.data[start] == ' ' || s.data[start] == '\t' || s.data[start] == '\n' || s.data[start] == '\r')) {
        start++;
    }
    int end = s.len;
    while (end > start && (s.data[end - 1] == ' ' || s.data[end - 1] == '\t' || s.data[end - 1] == '\n' || s.data[end - 1] == '\r')) {
        end--;
    }
    Slice_unsigned_char res;
    res.data = s.data + start;
    res.len = end - start;
    return res;
}


unsigned char std_is_alpha(unsigned char b) {
    return ((b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_') ? 1 : 0;
}

unsigned char std_is_digit(unsigned char b) {
    return (b >= '0' && b <= '9') ? 1 : 0;
}

unsigned char std_is_whitespace(unsigned char b) {
    return (b == ' ' || b == '\t' || b == '\n' || b == '\r') ? 1 : 0;
}

int std_parse_int(Slice_unsigned_char s) {
    if (s.len <= 0) return 0;
    int index = 0;
    int sign = 1;
    if (s.data[0] == '-') {
        sign = -1;
        index = 1;
    } else if (s.data[0] == '+') {
        index = 1;
    }
    int result = 0;
    for (; index < s.len; index++) {
        unsigned char c = s.data[index];
        if (c >= '0' && c <= '9') {
            result = result * 10 + (c - '0');
        } else {
            break;
        }
    }
    return result * sign;
}

/* Patch 25.5: std_Clone_str and std_str_split are NOT here any more. Both
   need N raw bytes from a caller-supplied arena and Gust has no spelling
   for that -- os.ArenaAlloc takes one argument, the allocator, because
   Gust allocates by TYPE through ctx[T]. They went to src/runtime-rs under
   D2's per-file fallback, and leaving the C copies here would collide with
   the crate's single archive member. The other nine follow them out next
   patch, to Gust; compiler/runtime/strings.gst already holds them and
   scripts/phase25_strings_gust_parity.sh already compares them against a
   frozen copy of this file. */
