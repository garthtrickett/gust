// Patch 21.3 complete executable no-op surface.
// The scoped declarations and query clauses are compiler-owned syntax, while
// the observable value remains exactly the terminal expression.

#[scoped(workspace_id)]
type Phase21WorkspaceRow struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21MemberRow struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21AuditRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut workspace_scope_phase21_3 := 7;
    mut member_scope_phase21_3 := 7;
    return query {
        root Phase21WorkspaceRow as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21MemberRow as member predicate member.workspace_id == trusted_scope_from_context("workspace_id");
        nested query {
            root Phase21AuditRow as audit;
            predicate audit.workspace_id == trusted_scope_from_context("workspace_id");
            terminal 11;
        };
        cross_tenant cross_tenant_capability_from_host();
        terminal 37;
    };
}
