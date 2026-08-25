#[scoped(workspace_id)]
type Phase21NestedAggregateRoot struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21NestedAggregateRoot as outer_workspace;
        predicate outer_workspace.workspace_id == trusted_scope_from_context("workspace_id");
        nested query {
            root Phase21NestedAggregateRoot as aggregate_workspace;
            predicate aggregate_workspace.workspace_id == trusted_scope_from_context("workspace_id");
            terminal 20 + 1;
        };
        terminal 55;
    };
}
