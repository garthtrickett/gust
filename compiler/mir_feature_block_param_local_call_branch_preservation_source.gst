func tiny_block_param_local_call_branch(input: int) int {
    mut called := input + 1;
    if called > 0 {
        return 79;
    }
    return 83;
}