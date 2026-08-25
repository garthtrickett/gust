#[scoped(workspace_id)]
type Phase21QueryValueFlowRoot struct {
    workspace_id: int,
    value: int
}

func selected_query_value(select_first: int) int {
    if select_first == 1 {
        return query {
            root Phase21QueryValueFlowRoot as first_workspace;
            predicate first_workspace.workspace_id == trusted_scope_from_context("workspace_id");
            terminal 52;
        };
    }
    return query {
        root Phase21QueryValueFlowRoot as second_workspace;
        predicate second_workspace.workspace_id == trusted_scope_from_context("workspace_id");
        terminal 53;
    };
}

func main() int {
    mut returned_query_value := selected_query_value(1);
    mut aliased_query_value := returned_query_value;
    return aliased_query_value;
}
