func tiny_block_param_imported_call_branch(input: int) int {
    mut called := input - 3;
    if called > 0 {
        return 89;
    }
    return 97;
}