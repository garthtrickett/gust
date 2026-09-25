// Byte-oriented predicates over str. Empty needles match every haystack.
func starts_with(haystack: str, needle: str) int {
    mut needle_len := len(needle);
    if needle_len > len(haystack) { return 0; }
    if needle_len == 0 { return 1; }
    return std.str_eq(std.str_slice(haystack, 0, needle_len), needle);
}

func ends_with(haystack: str, needle: str) int {
    mut haystack_len := len(haystack);
    mut needle_len := len(needle);
    if needle_len > haystack_len { return 0; }
    if needle_len == 0 { return 1; }
    return std.str_eq(std.str_slice(haystack, haystack_len - needle_len, haystack_len), needle);
}

func contains(haystack: str, needle: str) int {
    if len(needle) > len(haystack) { return 0; }
    if len(needle) == 0 { return 1; }
    if std.str_find(haystack, needle) == 0 - 1 { return 0; }
    return 1;
}
