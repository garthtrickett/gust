#[scoped(workspace_id)]
type Phase21QueryValueBranchRoot struct {
    workspace_id: int,
    value: int
}

func selected_query_value(select_first: int) int {
    if select_first == 1 {
        return query {
            root Phase21QueryValueBranchRoot as first_workspace;
            predicate first_workspace.workspace_id == trusted_scope_from_context("workspace_id");
            terminal 65;
        };
    }
    return query {
        root Phase21QueryValueBranchRoot as second_workspace;
        terminal 66;
    };
}

func main() int {
    return selected_query_value(1);
}
