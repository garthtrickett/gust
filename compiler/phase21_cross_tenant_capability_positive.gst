#[scoped(workspace_id)]
type Phase21CrossTenantWorkspace struct {
    workspace_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21CrossTenantMember struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21CrossTenantWorkspace as workspace;
        join Phase21CrossTenantMember as member predicate member.workspace_id == workspace.workspace_id;
        cross_tenant cross_tenant_capability_from_host();
        terminal 71;
    };
}
