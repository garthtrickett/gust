// Patch 25.5: the Gust half of the strings differential.
//
// Runs the same 27 value cases and 4 bounds-failure cases as
// tools/phase25_strings_reference.c, in the same order and the same output
// format, so `diff` is the whole assertion.
//
// Patch 25.10a: NOTHING DRIVES THIS TODAY. Its driver was
// scripts/phase25_strings_gust_parity.sh, which emitted the Gust side
// through the bootstrap emitter; that script is deleted and Patch 25.10
// removes the emitter. Running it needs the native route, which defers on
// compiler/runtime/strings.gst with
// capability=phase13_generic_source_to_mir.
//
// Kept rather than deleted, and the distinction matters: strings.gst is
// still the behavioural reference for src/runtime-rs/src/strings.rs, and
// this is its runnable form for whoever connects that capability. What
// checks the runtime TODAY is scripts/phase25_strings_rust_parity.sh,
// which compares the Rust against the retired C itself rather than
// against a hand-written reference.
//
// This is an ENTRY, not a library: it lives beside strings.gst rather than
// in compiler/ so the COMPILER_SRCS wildcard does not pick it up.

import "strings.gst" as rtstr;

func show(tag: str, v: int) {
    os.LogStr(tag);
    os.LogInt(v);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if len(args) > 1 {
        // Each of these aborts. The reference aborts identically; the script
        // compares message, stream and exit code.
        mut mode := std_str_byte_at(args[1], 0);
        if mode == 97 { std_str_slice("hello", 0, 10); }
        if mode == 98 { std_str_slice("hello", 3, 1); }
        if mode == 99 { std_str_slice("hello", 0 - 1, 2); }
        if mode == 100 { std_str_byte_at("hello", 9); }
        os.Exit(0);
    }

    show("eq_same", std_str_eq("abc", "abc"));
    show("eq_diff", std_str_eq("abc", "abd"));
    show("eq_len", std_str_eq("abc", "ab"));
    show("byte_at", std_str_byte_at("abc", 1) as int);
    show("alpha_a", std_is_alpha(97) as int);
    show("alpha_us", std_is_alpha(95) as int);
    show("alpha_0", std_is_alpha(48) as int);
    show("digit_5", std_is_digit(53) as int);
    show("digit_a", std_is_digit(97) as int);
    show("ws_sp", std_is_whitespace(32) as int);
    show("ws_a", std_is_whitespace(97) as int);
    show("find_hit", std_str_find("hello world", "wor"));
    show("find_miss", std_str_find("hello", "zz"));
    show("find_empty", std_str_find("hello", ""));
    show("find_toolong", std_str_find("hi", "hello"));
    show("parse_42", std_parse_int("42"));
    show("parse_neg", std_parse_int("-42"));
    show("parse_plus", std_parse_int("+7"));
    show("parse_junk", std_parse_int("12ab"));
    show("parse_empty", std_parse_int(""));
    show("parse_alpha", std_parse_int("abc"));
    os.LogStr("slice_mid");
    os.LogStr(std_str_slice("hello", 1, 3));
    show("slice_empty_tail", len(std_str_slice("hello", 5, 5)));
    show("slice_all", len(std_str_slice("hello", 0, 5)));
    os.LogStr("trim");
    os.LogStr(std_str_trim("  hi \t\n"));
    show("trim_allws", len(std_str_trim("   ")));
    show("trim_none", len(std_str_trim("ab")));
}
