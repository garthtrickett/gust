#[scoped(workspace_id)]
type Phase21ForgedWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func forged_scope_from_input(value: int) int {
    return value;
}

func main() int {
    mut attacker_controlled := 7;
    return query {
        root Phase21ForgedWorkspaceRow as workspace;
        predicate workspace.workspace_id == forged_scope_from_input(attacker_controlled);
        terminal 92;
    };
}
