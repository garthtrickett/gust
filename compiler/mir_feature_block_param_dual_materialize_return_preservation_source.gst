func tiny_block_param_dual_materialize_return_helper(value: int) int {
    return value + 3;
}

func tiny_block_param_dual_materialize_return(input: int) int {
    mut imported_probe := input - 5;
    mut local_probe := tiny_block_param_dual_materialize_return_helper(imported_probe);
    mut base := 523;
    if local_probe > 0 {
        base = 501;
    }
    return base + 17;
}