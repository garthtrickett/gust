func tiny_block_param_triple_materialize_return_helper(value: int) int {
    return value + 5;
}

func tiny_block_param_triple_materialize_return_exit_helper(value: int) int {
    return value + 6;
}

func tiny_block_param_triple_materialize_return(input: int) int {
    mut first_probe := input - 2;
    mut second_probe := tiny_block_param_triple_materialize_return_helper(first_probe);
    mut third_probe := second_probe - 4;
    mut base := 733;
    if third_probe > 0 {
        base = 701;
    }
    return tiny_block_param_triple_materialize_return_exit_helper(base);
}