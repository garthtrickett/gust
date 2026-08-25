// Patch 21.3 executable typed-query no-op baseline.
// witness_kind: intended_untrusted_scope_negative
// current_surface: compiler_owned_typed_query_syntax_without_scope_enforcement
// syntax_authority: patch21_3_contextual_query_and_scoped_entity_surface
// expected_transition: patch21_4_rejects_the_equivalent_typed_query_at_the_query

func main() int {
    mut attacker_controlled_scope_shape := 9;
    return query {
        root Phase21UntrustedWorkspaceRow as workspace;
        predicate workspace.workspace_id == attacker_controlled_scope_shape;
        terminal 99;
    };
}
