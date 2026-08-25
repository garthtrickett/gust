// Patch 21.1 executable query-shaped baseline.
// witness_kind: intended_untrusted_scope_negative
// current_surface: ordinary_user_values_no_compiler_owned_query_or_scope_provenance
// syntax_authority: none_exact_typed_query_spelling_belongs_to_patch21_3
// expected_transition: patch21_4_rejects_the_equivalent_typed_query_at_the_query

func main() int {
    mut attacker_controlled_scope_shape := 9;
    mut row_workspace_shape := attacker_controlled_scope_shape;
    if row_workspace_shape == attacker_controlled_scope_shape {
        return 99;
    }
    return 1;
}
