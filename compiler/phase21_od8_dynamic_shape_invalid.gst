#[scoped(workspace_id)]
type Phase21Od8DynamicWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut attacker_controlled_entity := "Phase21Od8DynamicWorkspace";
    return query {
        root (attacker_controlled_entity) as workspace;
        predicate workspace.workspace_id == attacker_controlled_entity;
        terminal 101;
    };
}
