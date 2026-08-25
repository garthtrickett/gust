#[scoped(workspace_id)]
type Phase21CrossTenantReexportWorkspace struct {
    workspace_id: int,
    value: int
}

func reexport_capability() int {
    cross_tenant_capability_from_host();
    return 1;
}

func main() int {
    return query {
        root Phase21CrossTenantReexportWorkspace as workspace;
        cross_tenant reexport_capability();
        terminal 75;
    };
}
