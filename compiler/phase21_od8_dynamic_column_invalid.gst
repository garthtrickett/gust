#[scoped(workspace_id)]
type Phase21Od8DynamicColumnWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut attacker_controlled_column := "workspace_id";
    return query {
        root Phase21Od8DynamicColumnWorkspace as workspace;
        predicate workspace.(attacker_controlled_column) == trusted_scope_from_context("workspace_id");
        terminal 102;
    };
}
