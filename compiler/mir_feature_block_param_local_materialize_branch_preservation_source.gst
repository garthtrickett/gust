func tiny_block_param_local_materialize_branch_helper(value: int) int {
    return value + 1;
}

func tiny_block_param_local_materialize_branch(input: int) int {
    mut probed := tiny_block_param_local_materialize_branch_helper(input);
    if probed > 0 {
        return 293;
    }
    return 307;
}