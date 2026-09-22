/* Patch 25.10a: differential driver for the nine pure string functions.
 *
 * Left side: whatever the runtime archive defines -- Rust, as of this
 * patch. Right side: oracle_*, the retired src/runtime/strings.c compiled
 * from its pinned git blob and renamed so both can be linked at once.
 *
 * The corpus is adversarial where the two could plausibly diverge rather
 * than uniform where they obviously agree:
 *
 *   - std_is_alpha accepts '_'. Rust's is_ascii_alphabetic does not, so
 *     every byte 0..255 is compared, not a sample.
 *   - std_is_whitespace is space/tab/LF/CR. Rust's is_ascii_whitespace
 *     also takes form feed, which would be a silent widening.
 *   - std_parse_int wraps on overflow in C and would PANIC in a Rust
 *     debug profile, so the corpus includes digit runs past INT_MAX.
 *   - std_str_find has the empty-target and target-longer-than-haystack
 *     edges, both of which return early in the C.
 *
 * Bounds failures are NOT exercised: std_str_bounds_fail calls exit(1) on
 * both sides, so a case that triggers it would end the run rather than
 * report. That path is asserted by its own inversion, not here.
 *
 * Prints the number of comparisons on stdout. The guard requires a
 * minimum, because a differential that runs nothing passes.
 */
#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif

#include <stdio.h>
#include <string.h>

int std_str_eq(Slice_unsigned_char, Slice_unsigned_char);
unsigned char std_str_byte_at(Slice_unsigned_char, int);
unsigned char std_is_alpha(unsigned char);
unsigned char std_is_digit(unsigned char);
unsigned char std_is_whitespace(unsigned char);
int std_str_find(Slice_unsigned_char, Slice_unsigned_char);
int std_parse_int(Slice_unsigned_char);
Slice_unsigned_char std_str_slice(Slice_unsigned_char, int, int);
Slice_unsigned_char std_str_trim(Slice_unsigned_char);

int oracle_std_str_eq(Slice_unsigned_char, Slice_unsigned_char);
unsigned char oracle_std_str_byte_at(Slice_unsigned_char, int);
unsigned char oracle_std_is_alpha(unsigned char);
unsigned char oracle_std_is_digit(unsigned char);
unsigned char oracle_std_is_whitespace(unsigned char);
int oracle_std_str_find(Slice_unsigned_char, Slice_unsigned_char);
int oracle_std_parse_int(Slice_unsigned_char);
Slice_unsigned_char oracle_std_str_slice(Slice_unsigned_char, int, int);
Slice_unsigned_char oracle_std_str_trim(Slice_unsigned_char);

static long comparisons = 0;
static int failures = 0;

static void check(int ok, const char *what, const char *detail) {
    comparisons++;
    if (!ok) {
        failures++;
        fprintf(stderr, "DISAGREE %s: %s\n", what, detail);
    }
}

static Slice_unsigned_char sl(const char *s) {
    Slice_unsigned_char out;
    out.data = (unsigned char *)s;
    out.len = (int)strlen(s);
    return out;
}

static const char *CORPUS[] = {
    "", " ", "  ", "\t", "\n", "\r", "\f", " \t\n\r ",
    "a", "Z", "_", "0", "9", "-", "+",
    "abc", "ABC", "_abc_", "a_b_c",
    "hello world", "  hello world  ", "\t\nhello\r\n",
    "0", "7", "42", "-42", "+42", "007", "-0", "+0",
    "2147483647", "2147483648", "9999999999", "-2147483648",
    "-9999999999", "12x", "x12", "1 2", "--1", "++1", "-+1",
    "the quick brown fox", "aaaaab", "aaaaaa", "ababab",
    "needle", "haystack", "hayneedlestack", "needlehaystack",
    "hay", "\0hidden",
};
static const int CORPUS_N = (int)(sizeof(CORPUS) / sizeof(CORPUS[0]));

int main(void) {
    for (int b = 0; b < 256; b++) {
        unsigned char c = (unsigned char)b;
        char detail[64];
        snprintf(detail, sizeof detail, "byte %d", b);
        check(std_is_alpha(c) == oracle_std_is_alpha(c), "is_alpha", detail);
        check(std_is_digit(c) == oracle_std_is_digit(c), "is_digit", detail);
        check(std_is_whitespace(c) == oracle_std_is_whitespace(c),
              "is_whitespace", detail);
    }

    for (int i = 0; i < CORPUS_N; i++) {
        Slice_unsigned_char s = sl(CORPUS[i]);
        char detail[128];
        snprintf(detail, sizeof detail, "case %d %.40s", i, CORPUS[i]);

        check(std_parse_int(s) == oracle_std_parse_int(s), "parse_int", detail);

        Slice_unsigned_char t1 = std_str_trim(s);
        Slice_unsigned_char t2 = oracle_std_str_trim(s);
        check(t1.len == t2.len && t1.data == t2.data, "str_trim", detail);

        for (int j = 0; j < s.len; j++) {
            check(std_str_byte_at(s, j) == oracle_std_str_byte_at(s, j),
                  "str_byte_at", detail);
        }
        for (int start = 0; start <= s.len; start++) {
            for (int end = start; end <= s.len; end++) {
                Slice_unsigned_char a = std_str_slice(s, start, end);
                Slice_unsigned_char b2 = oracle_std_str_slice(s, start, end);
                check(a.len == b2.len && a.data == b2.data, "str_slice", detail);
            }
        }
        for (int j = 0; j < CORPUS_N; j++) {
            Slice_unsigned_char other = sl(CORPUS[j]);
            check(std_str_eq(s, other) == oracle_std_str_eq(s, other),
                  "str_eq", detail);
            check(std_str_find(s, other) == oracle_std_str_find(s, other),
                  "str_find", detail);
        }
    }

    if (failures) {
        fprintf(stderr, "%d disagreements across %ld comparisons\n",
                failures, comparisons);
        return 1;
    }
    printf("%ld\n", comparisons);
    return 0;
}
