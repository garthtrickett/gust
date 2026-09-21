/* Patch 25.5: the FROZEN C reference for compiler/runtime/strings.gst.
 *
 * A verbatim copy of the nine functions of src/runtime/strings.c that moved
 * to Gust, taken at the commit that deleted that file. It exists so the
 * differential outlives its subject: once strings.c is gone, "the Gust port
 * matches the C" has nothing to compare against, and a later edit to
 * strings.gst would be checked only against itself.
 *
 * DO NOT "fix" anything here. Divergence from this file is exactly what the
 * harness is for, and a change here makes the comparison agree by moving
 * the control -- see the lane note on ports keeping the reference number.
 *
 * std_str_split and std_Clone_str are absent: they need arena bytes Gust
 * cannot ask for and stayed in the Rust crate, so there is nothing to
 * compare. Their absence also lets this file link standalone.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { unsigned char* data; int len; } Slice_unsigned_char;

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


/* The same 27 cases the Gust entry runs, in the same order and format. */
static Slice_unsigned_char S(const char* s){
    Slice_unsigned_char r; r.data=(unsigned char*)s; r.len=(int)strlen(s); return r;
}
static void show(const char* tag, int v){ printf("%s\n%d\n", tag, v); }
static void logs(Slice_unsigned_char s){ fwrite(s.data,1,s.len,stdout); putchar('\n'); }

int main(int argc, char** argv){
  if (argc > 1) {
    Slice_unsigned_char s = S("hello");
    if (argv[1][0]=='a') std_str_slice(s, 0, 10);
    if (argv[1][0]=='b') std_str_slice(s, 3, 1);
    if (argv[1][0]=='c') std_str_slice(s, -1, 2);
    if (argv[1][0]=='d') std_str_byte_at(s, 9);
    return 0;
  }
  show("eq_same", std_str_eq(S("abc"), S("abc")));
  show("eq_diff", std_str_eq(S("abc"), S("abd")));
  show("eq_len",  std_str_eq(S("abc"), S("ab")));
  show("byte_at", (int)std_str_byte_at(S("abc"), 1));
  show("alpha_a", (int)std_is_alpha(97));
  show("alpha_us",(int)std_is_alpha(95));
  show("alpha_0", (int)std_is_alpha(48));
  show("digit_5", (int)std_is_digit(53));
  show("digit_a", (int)std_is_digit(97));
  show("ws_sp",   (int)std_is_whitespace(32));
  show("ws_a",    (int)std_is_whitespace(97));
  show("find_hit",     std_str_find(S("hello world"), S("wor")));
  show("find_miss",    std_str_find(S("hello"), S("zz")));
  show("find_empty",   std_str_find(S("hello"), S("")));
  show("find_toolong", std_str_find(S("hi"), S("hello")));
  show("parse_42",    std_parse_int(S("42")));
  show("parse_neg",   std_parse_int(S("-42")));
  show("parse_plus",  std_parse_int(S("+7")));
  show("parse_junk",  std_parse_int(S("12ab")));
  show("parse_empty", std_parse_int(S("")));
  show("parse_alpha", std_parse_int(S("abc")));
  printf("slice_mid\n"); logs(std_str_slice(S("hello"), 1, 3));
  show("slice_empty_tail", std_str_slice(S("hello"), 5, 5).len);
  show("slice_all",        std_str_slice(S("hello"), 0, 5).len);
  printf("trim\n"); logs(std_str_trim(S("  hi \t\n")));
  show("trim_allws", std_str_trim(S("   ")).len);
  show("trim_none",  std_str_trim(S("ab")).len);
  return 0;
}
