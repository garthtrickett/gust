#[scoped(workspace_id)]
type Phase21CrossTenantNestedWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21CrossTenantNestedWorkspace as outer_workspace;
        cross_tenant cross_tenant_capability_from_host();
        nested query {
            root Phase21CrossTenantNestedWorkspace as inner_workspace;
            terminal 1;
        };
        terminal 76;
    };
}
