func tiny_block_param_imported_predicate_update_branch(input: int) int {
    mut predicated := input - 4;
    if predicated > 0 {
        return 101;
    }
    return 107;
}