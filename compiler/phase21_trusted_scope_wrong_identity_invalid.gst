#[scoped(workspace_id)]
type Phase21WrongWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21WrongWorkspaceRow as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("organization_id");
        terminal 93;
    };
}
