#[scoped(workspace_id)]
type Phase21Od8StoreWorkspace struct {
    workspace_id: int,
    value: int
}

type Phase21Od8ScopeBox struct {
    value: int
}

func main() int {
    mut stored_scope: Phase21Od8ScopeBox;
    stored_scope.value = trusted_scope_from_context("workspace_id");
    return query {
        root Phase21Od8StoreWorkspace as workspace;
        predicate workspace.workspace_id == stored_scope.value;
        terminal 106;
    };
}
