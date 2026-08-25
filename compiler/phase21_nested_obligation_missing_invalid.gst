#[scoped(workspace_id)]
type Phase21NestedRoot struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21NestedRoot as outer_workspace;
        predicate outer_workspace.workspace_id == trusted_scope_from_context("workspace_id");
        nested query {
            root Phase21NestedRoot as inner_workspace;
            terminal 1;
        };
        terminal 63;
    };
}
