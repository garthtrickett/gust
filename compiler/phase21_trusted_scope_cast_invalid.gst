#[scoped(workspace_id)]
type Phase21CastWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut attacker_controlled_scope := 7;
    return query {
        root Phase21CastWorkspaceRow as workspace;
        predicate workspace.workspace_id == (attacker_controlled_scope as int);
        terminal 95;
    };
}
