#[scoped(workspace_id)]
type Phase21SiblingRoot struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21SiblingJoin struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21SiblingRoot as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21SiblingJoin as first_member predicate first_member.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21SiblingJoin as second_member predicate second_member.workspace_id == first_member.workspace_id;
        terminal 62;
    };
}
