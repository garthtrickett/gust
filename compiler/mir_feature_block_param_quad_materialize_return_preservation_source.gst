func tiny_block_param_quad_materialize_return_helper(value: int) int {
    return value + 2;
}

func tiny_block_param_quad_materialize_return_second_helper(value: int) int {
    return value + 4;
}

func tiny_block_param_quad_materialize_return(input: int) int {
    mut first_probe := tiny_block_param_quad_materialize_return_helper(input);
    mut second_probe := first_probe - 3;
    mut third_probe := tiny_block_param_quad_materialize_return_second_helper(second_probe);
    mut fourth_probe := third_probe - 5;
    mut base := 853;
    if fourth_probe > 0 {
        base = 811;
    }
    return base + 19;
}