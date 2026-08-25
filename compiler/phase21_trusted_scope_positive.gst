#[scoped(workspace_id)]
type Phase21ScopedWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21ScopedWorkspaceRow as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        terminal 41;
    };
}
