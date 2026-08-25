#[scoped(workspace_id)]
type Phase21Od8ReturnLaunderWorkspace struct {
    workspace_id: int,
    value: int
}

func launder_scope_through_return() int {
    return trusted_scope_from_context("workspace_id");
}

func main() int {
    return query {
        root Phase21Od8ReturnLaunderWorkspace as workspace;
        predicate workspace.workspace_id == launder_scope_through_return();
        terminal 104;
    };
}
