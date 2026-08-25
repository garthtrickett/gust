#[scoped(workspace_id)]
type Phase21ArbitraryWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut attacker_controlled_scope := 7;
    return query {
        root Phase21ArbitraryWorkspaceRow as workspace;
        predicate workspace.workspace_id == attacker_controlled_scope;
        terminal 94;
    };
}
