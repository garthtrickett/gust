// Patch 25.5: strings.c to Gust, the pure half.
//
// Nine of strings.c's eleven functions, each emitting a C signature
// BYTE-IDENTICAL to the original it replaces -- verified against
// src/runtime/strings.c, not by eye:
//
//   int           std_str_eq(Slice_unsigned_char, Slice_unsigned_char)
//   unsigned char std_str_byte_at(Slice_unsigned_char, int)
//   unsigned char std_is_alpha(unsigned char)
//   unsigned char std_is_digit(unsigned char)
//   unsigned char std_is_whitespace(unsigned char)
//   int           std_str_find(Slice_unsigned_char, Slice_unsigned_char)
//   int           std_parse_int(Slice_unsigned_char)
//   Slice_unsigned_char std_str_slice(Slice_unsigned_char, int, int)
//   Slice_unsigned_char std_str_trim(Slice_unsigned_char)
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
// NOT ported: std_Clone_str and std_str_split. Both need N raw bytes
// from a caller-supplied arena, and Gust has no spelling for that --
// os.ArenaAlloc takes one argument, the allocator, because Gust
// allocates by TYPE through ctx[T], and there is no Gust spelling for
// "give me N raw bytes from this arena". os.ScratchAlloc does take a byte
// count, but scratch resets and a clone must outlive the scope. See the
// roadmap: recommendation is to leave those two in the Rust crate under
// D2's per-file fallback.

func std_str_eq(s1: str, s2: str) int {
    if len(s1) != len(s2) { return 0; }
    mut i := 0;
    while i < len(s1) {
        if s1[i] != s2[i] { return 0; }
        i = i + 1;
    }
    return 1;
}

// The explicit checks are not redundant with the subscript's. `s[idx]`
// does emit a bounds check -- measured in the emitted C, not assumed -- so
// the safety property was never lost. What differed was the DIAGNOSTIC: the
// subscript aborts with "Slice bounds check failed at line 85" on stderr
// where the C printed "std.str_byte_at bounds check failed" on stdout. Same
// exit code, different message and stream, which is enough to break a
// caller matching on output. Checked here so the two agree exactly.
func std_str_byte_at(s: str, idx: int) byte {
    if idx < 0 { std_str_bounds_fail("std.str_byte_at bounds check failed"); }
    if idx >= len(s) { std_str_bounds_fail("std.str_byte_at bounds check failed"); }
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

type StrHeader struct {
    data: *byte,
    len: int
}

// The C's printf-then-exit(1), reproduced. os.LogStr writes the message to
// stdout with a newline, which is what printf did; the subscript's own
// gust_check_fail writes to stderr and names no function.
//
// This is the one symbol in this file that has no counterpart in
// strings.c. It is file-level, so it emits as a bare `std_str_bounds_fail`
// alongside the nine.
func std_str_bounds_fail(what: str) {
    os.LogStr(what);
    os.Exit(1);
}

// Two things here were WRONG in the first draft, both found by emitting the
// C and running it rather than by reading it.
//
// The three explicit bounds checks are not belt-and-braces. `s[start]`
// emits its own check, and the first draft leaned on it -- but it tests
// `start >= s.len`, where the C tests `end > s.len`. So `str_slice(s, 0,
// s.len + 5)` sailed past and returned an over-long slice where the C
// aborted, and `str_slice(s, s.len, s.len)` -- the empty tail slice, which
// is legal in C and extremely common -- ABORTED. The subscript's check
// answers a different question, so the C's three are written out.
//
// Reading `s.data` through a StrHeader view rather than taking `&s[start]`
// is what makes the empty case work at all: there is no valid subscript to
// take when start == len.
//
// The header is a STACK local, not 16 bytes of scratch. The scratch version
// worked, and this file's earlier note recorded its cost honestly -- 16
// bytes per call across 165 call sites in the compiler's own sources. It
// turns out to be avoidable: a local struct emits `StrHeader hdr` and the
// return copies it out by value, so the port is now allocation-free, like
// the C. The recorded difference is gone rather than merely measured.
func std_str_slice(s: str, start: int, end: int) str {
    if start < 0 { std_str_bounds_fail("std.str_slice bounds check failed"); }
    if end < start { std_str_bounds_fail("std.str_slice bounds check failed"); }
    if end > len(s) { std_str_bounds_fail("std.str_slice bounds check failed"); }
    mut hdr: StrHeader;
    unsafe {
        mut sp := (&s) as *StrHeader;
        hdr.data = (*sp).data + start;
        hdr.len = end - start;
        mut hp := (&hdr) as *StrHeader;
        return *(((hp as *str) + 0) as *str);
    }
}

// `c - 48` on a `byte` promotes exactly as the C's `c - '0'` does; measured
// in the emitted C rather than assumed, since `byte` is `unsigned char` and
// a narrowing here would wrap silently.
//
// Overflow is UNCHECKED, as in the C: a 12-digit input wraps. Callers parse
// their own emitted integers, so nothing in tree reaches it, but the port
// does not quietly acquire a check the original did not have.
func std_parse_int(s: str) int {
    if len(s) <= 0 { return 0; }
    mut index := 0;
    mut sign := 1;
    mut c0 := s[0];
    if c0 == 45 { sign = 0 - 1; index = 1; }
    else { if c0 == 43 { index = 1; } }
    mut result := 0;
    mut go := 1;
    while go == 1 {
        if index >= len(s) { go = 0; }
        else {
            mut c := s[index];
            if c >= 48 {
                if c <= 57 { result = ((result * 10) + (c - 48)); index = index + 1; }
                else { go = 0; }
            } else { go = 0; }
        }
    }
    return result * sign;
}

func std_str_trim(s: str) str {
    mut start := 0;
    mut go := 1;
    while go == 1 {
        if start >= len(s) { go = 0; }
        else {
            mut c := s[start];
            if c == 32 { start = start + 1; }
            else { if c == 9 { start = start + 1; }
            else { if c == 10 { start = start + 1; }
            else { if c == 13 { start = start + 1; } else { go = 0; } } } }
        }
    }
    mut e := len(s);
    mut go2 := 1;
    while go2 == 1 {
        if e <= start { go2 = 0; }
        else {
            mut c2 := s[e - 1];
            if c2 == 32 { e = e - 1; }
            else { if c2 == 9 { e = e - 1; }
            else { if c2 == 10 { e = e - 1; }
            else { if c2 == 13 { e = e - 1; } else { go2 = 0; } } } }
        }
    }
    return std_str_slice(s, start, e);
}
