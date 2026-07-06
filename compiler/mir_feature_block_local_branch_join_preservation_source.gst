func tiny_block_local_branch_join(input: int) int {
    mut value := input;
    if value > 0 {
        value = value + 4;
    } else {
        value = value + 8;
    }
    return value;
}