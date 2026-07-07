func tiny_block_param_imported_materialize_return(input: int) int {
    mut probed := input - 5;
    mut base := 347;
    if probed > 0 {
        base = 331;
    }
    return base + 13;
}