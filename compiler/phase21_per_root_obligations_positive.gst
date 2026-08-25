#[scoped(workspace_id)]
type Phase21WorkspaceRoot struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21MemberJoin struct {
    workspace_id: int,
    value: int
}

#[scoped(organization_id)]
type Phase21AuditJoin struct {
    organization_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21WorkspaceRoot as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21MemberJoin as member predicate member.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21AuditJoin as audit predicate audit.organization_id == trusted_scope_from_context("organization_id");
        nested query {
            root Phase21WorkspaceRoot as nested_workspace;
            predicate nested_workspace.workspace_id == trusted_scope_from_context("workspace_id");
            terminal 1;
        };
        terminal 51;
    };
}
