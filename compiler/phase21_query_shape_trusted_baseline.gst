// Patch 21.1 executable query-shaped baseline.
// witness_kind: intended_trusted_scope_positive
// current_surface: ordinary_user_values_no_compiler_owned_query_or_scope_provenance
// syntax_authority: none_exact_typed_query_spelling_belongs_to_patch21_3
// expected_transition: patch21_4_accepts_the_equivalent_typed_query_only_with_trusted_scope_provenance

func main() int {
    mut trusted_scope_shape := 7;
    mut row_workspace_shape := 7;
    if row_workspace_shape == trusted_scope_shape {
        return 21;
    }
    return 1;
}
