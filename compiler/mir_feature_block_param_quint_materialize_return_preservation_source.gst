func tiny_block_param_quint_materialize_return_helper(value: int) int {
    return value + 2;
}

func tiny_block_param_quint_materialize_return_second_helper(value: int) int {
    return value + 4;
}

func tiny_block_param_quint_materialize_return_exit_helper(value: int) int {
    return value + 8;
}

func tiny_block_param_quint_materialize_return(input: int) int {
    mut first_probe := input - 1;
    mut second_probe := tiny_block_param_quint_materialize_return_helper(first_probe);
    mut third_probe := second_probe - 3;
    mut fourth_probe := tiny_block_param_quint_materialize_return_second_helper(third_probe);
    mut fifth_probe := fourth_probe - 5;
    mut base := 967;
    if fifth_probe > 0 {
        base = 919;
    }
    return tiny_block_param_quint_materialize_return_exit_helper(base);
}