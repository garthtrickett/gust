#[scoped(workspace_id)]
type Phase21CrossTenantArityWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21CrossTenantArityWorkspace as workspace;
        cross_tenant cross_tenant_capability_from_host(1);
        terminal 79;
    };
}
