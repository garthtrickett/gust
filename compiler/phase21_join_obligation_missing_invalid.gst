#[scoped(workspace_id)]
type Phase21JoinMissingRoot struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21JoinMissingMember struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21JoinMissingRoot as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21JoinMissingMember as member predicate member.workspace_id == workspace.workspace_id;
        terminal 61;
    };
}
