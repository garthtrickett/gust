func tiny_block_param_local_first_dual_materialize_return_helper(value: int) int {
    return value + 4;
}

func tiny_block_param_local_first_dual_materialize_return(input: int) int {
    mut local_probe := tiny_block_param_local_first_dual_materialize_return_helper(input);
    mut imported_probe := local_probe - 7;
    mut base := 631;
    if imported_probe > 0 {
        base = 601;
    }
    return tiny_block_param_local_first_dual_materialize_return_helper(base);
}