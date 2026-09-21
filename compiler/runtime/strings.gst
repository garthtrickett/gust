// Patch 25.5: strings.c to Gust, the pure half.
//
// Six of strings.c's eleven functions, each emitting a C signature
// BYTE-IDENTICAL to the original it replaces -- verified against
// src/runtime/strings.c, not by eye:
//
//   int           std_str_eq(Slice_unsigned_char, Slice_unsigned_char)
//   unsigned char std_str_byte_at(Slice_unsigned_char, int)
//   unsigned char std_is_alpha(unsigned char)
//   unsigned char std_is_digit(unsigned char)
//   unsigned char std_is_whitespace(unsigned char)
//   int           std_str_find(Slice_unsigned_char, Slice_unsigned_char)
//
// `byte` is what makes that exact: it maps to `unsigned char`
// (codegen.gst:66). Declaring these `int` compiles and emits the wrong
// prototype -- the four byte-typed ones silently became int/int, which no
// caller would see until a prototype check or a differing ABI caught it.
//
// Two language facts this needed, both measured rather than assumed:
// negative literals are written `0 - 1` (the compiler's own sources do so
// 597 times, and `return -1;` is a parse error here); and `s[i]` emits
// `s.data[i]` directly, so nothing calls std_str_byte_at to implement
// std_str_byte_at.
//
// NOT ported here: std_str_slice, std_str_trim, std_str_split,
// std_parse_int and std_Clone_str. The first two build a str from a
// pointer and length, the last three need the arena -- all four are
// questions about expressing runtime types in Gust, which is a different
// problem from pure byte computation and belongs in its own commit.

func std_str_eq(s1: str, s2: str) int {
    if len(s1) != len(s2) { return 0; }
    mut i := 0;
    while i < len(s1) {
        if s1[i] != s2[i] { return 0; }
        i = i + 1;
    }
    return 1;
}

func std_str_byte_at(s: str, idx: int) byte {
    return s[idx];
}

func std_is_alpha(b: byte) byte {
    if b >= 97 { if b <= 122 { return 1; } }
    if b >= 65 { if b <= 90 { return 1; } }
    if b == 95 { return 1; }
    return 0;
}

func std_is_digit(b: byte) byte {
    if b >= 48 { if b <= 57 { return 1; } }
    return 0;
}

func std_is_whitespace(b: byte) byte {
    if b == 32 { return 1; }
    if b == 9  { return 1; }
    if b == 10 { return 1; }
    if b == 13 { return 1; }
    return 0;
}

func std_str_find(s: str, target: str) int {
    if len(target) == 0 { return 0; }
    if len(s) < len(target) { return 0 - 1; }
    mut i := 0;
    while i <= len(s) - len(target) {
        mut j := 0;
        mut hit := 1;
        while j < len(target) {
            if s[i + j] != target[j] { hit = 0; j = len(target); }
            else { j = j + 1; }
        }
        if hit == 1 { return i; }
        i = i + 1;
    }
    return 0 - 1;
}
