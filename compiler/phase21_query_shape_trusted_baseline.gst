// Patch 21.3 executable typed-query no-op baseline.
// witness_kind: intended_trusted_scope_positive
// current_surface: compiler_owned_typed_query_syntax_without_scope_enforcement
// syntax_authority: patch21_3_contextual_query_and_scoped_entity_surface
// expected_transition: patch21_4_accepts_the_equivalent_typed_query_only_with_trusted_scope_provenance

func main() int {
    mut trusted_scope_shape := 7;
    return query {
        root Phase21TrustedWorkspaceRow as workspace;
        predicate workspace.workspace_id == trusted_scope_shape;
        terminal 21;
    };
}
