// Stdlib S1.2: regression coverage for the string surface, pinned before
// anything changes it. The operation list is taken from
// docs/STDLIB_SURFACE_INVENTORY.md, not from memory.
//
// Out-of-range behaviour is deliberately NOT exercised here. std_str_slice and
// std_str_byte_at print and call exit(1) on a bad index, which would terminate
// this program rather than report a failure. That behaviour is recorded as an
// observed fact in TASK_STDLIB.md CR-3 and is not changed by this patch.
//
// GEMINI.md section A: a struct holding a `str` field must be a branded
// template. GEMINI.md section C: local names are unique across the function.

type StrHolder[ctx] struct {
    held: str
}

func take_param(param_value: str) int {
    return len(param_value);
}

func give_return(ctx: &Arena) str {
    return std.Clone(ctx, "returned");
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    // --- position: local ---
    mut local_value: str := "hello,world";
    os.LogInt(len(local_value));                       // 11

    // --- len boundaries ---
    mut empty_value: str := "";
    os.LogInt(len(empty_value));                       // 0

    // --- byte access: first, middle, final ---
    os.LogInt(std.str_byte_at(local_value, 0));        // 104 'h'
    os.LogInt(std.str_byte_at(local_value, 5));        // 44  ','
    os.LogInt(std.str_byte_at(local_value, 10));       // 100 'd'

    // --- slice: empty, whole, prefix, suffix, middle ---
    mut slice_empty := std.str_slice(local_value, 0, 0);
    os.LogInt(len(slice_empty));                       // 0
    mut slice_whole := std.str_slice(local_value, 0, 11);
    os.LogInt(len(slice_whole));                       // 11
    mut slice_prefix := std.str_slice(local_value, 0, 5);
    os.LogStr(slice_prefix);                           // hello
    mut slice_suffix := std.str_slice(local_value, 6, 11);
    os.LogStr(slice_suffix);                           // world
    mut slice_middle := std.str_slice(local_value, 4, 7);
    os.LogStr(slice_middle);                           // o,w

    // --- find: present, absent, empty needle ---
    os.LogInt(std.str_find(local_value, "world"));     // 6
    os.LogInt(std.str_find(local_value, "absent"));    // -1
    os.LogInt(std.str_find(local_value, ""));          // 0

    // --- trim: padded, already trimmed, empty ---
    os.LogStr(std.str_trim("  padded  "));             // padded
    os.LogStr(std.str_trim("tight"));                  // tight
    os.LogInt(len(std.str_trim("   ")));               // 0

    // --- equality: equal, unequal, empty pair ---
    os.LogInt(std.str_eq(local_value, "hello,world")); // 1
    os.LogInt(std.str_eq(local_value, "hello,worlD")); // 0
    os.LogInt(std.str_eq(empty_value, ""));            // 1

    // --- position: function parameter ---
    os.LogInt(take_param(local_value));                // 11

    // --- position: return value ---
    mut returned_value := give_return(ctx);
    os.LogInt(len(returned_value));                    // 8

    // --- position: struct field ---
    mut holder_value: StrHolder[ctx];
    holder_value.held = "field";
    os.LogInt(len(holder_value.held));                 // 5
    os.LogInt(std.str_byte_at(holder_value.held, 0));  // 102 'f'

    // --- position: arena-cloned string ---
    mut cloned_value := std.Clone(ctx, local_value);
    os.LogInt(len(cloned_value));                      // 11
    os.LogInt(std.str_eq(cloned_value, local_value));  // 1

    // --- position: string produced by split ---
    mut split_parts := std.str_split(local_value, ",", ctx);
    os.LogInt(len(split_parts));                       // 2
    mut split_first := split_parts[0];
    os.LogStr(split_first);                            // hello
    os.LogInt(len(split_first));                       // 5
    mut split_second := split_parts[1];
    os.LogStr(split_second);                           // world

    // --- character classification and parsing over a byte from a str ---
    os.LogInt(std.is_alpha(std.str_byte_at(local_value, 0)));   // 1
    os.LogInt(std.is_digit(std.str_byte_at(local_value, 0)));   // 0
    os.LogInt(std.is_whitespace(std.str_byte_at("  x", 0)));    // 1
    os.LogInt(std.parse_int("42"));                             // 42

    os.LogStr("SUCCESS: str surface regression");
}
