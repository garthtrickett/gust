// Phase 17.8 pure Gust runtime module: character classification.
//
// These are ordinary Gust functions. They compile through generic parsing,
// typechecking, canonical MIR, ABI, and Cranelift lowering with no bespoke
// recognition of this file's name or contents anywhere in the compiler or
// backend. Replacing the C implementations in src/runtime/strings.c does not
// require the compiler to know that this module is "the runtime".
//
// Declared boundaries:
//   initialization: none_required_pure_functions
//   failure:        total_cannot_fail
//   dependencies:   none

func gust_rt_is_digit(byte: int) int {
    if byte >= 48 && byte <= 57 { return 1; }
    return 0;
}

func gust_rt_is_lower(byte: int) int {
    if byte >= 97 && byte <= 122 { return 1; }
    return 0;
}

func gust_rt_is_upper(byte: int) int {
    if byte >= 65 && byte <= 90 { return 1; }
    return 0;
}

func gust_rt_is_alpha(byte: int) int {
    if gust_rt_is_lower(byte) == 1 { return 1; }
    if gust_rt_is_upper(byte) == 1 { return 1; }
    return 0;
}

func gust_rt_is_whitespace(byte: int) int {
    if byte == 32 { return 1; }
    if byte == 9 { return 1; }
    if byte == 10 { return 1; }
    if byte == 13 { return 1; }
    return 0;
}

func gust_rt_is_alphanumeric(byte: int) int {
    if gust_rt_is_alpha(byte) == 1 { return 1; }
    if gust_rt_is_digit(byte) == 1 { return 1; }
    return 0;
}
