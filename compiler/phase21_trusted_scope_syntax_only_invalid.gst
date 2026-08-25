#[scoped(workspace_id)]
type Phase21SyntaxWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut trusted_scope_from_context_spelling := 7;
    return query {
        root Phase21SyntaxWorkspaceRow as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context_spelling;
        terminal 96;
    };
}
