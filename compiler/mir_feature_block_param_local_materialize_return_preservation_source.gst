func tiny_block_param_local_materialize_return_helper(value: int) int {
    return value + 2;
}

func tiny_block_param_local_materialize_return(input: int) int {
    mut probed := tiny_block_param_local_materialize_return_helper(input);
    mut base := 421;
    if probed > 0 {
        base = 401;
    }
    return tiny_block_param_local_materialize_return_helper(base);
}