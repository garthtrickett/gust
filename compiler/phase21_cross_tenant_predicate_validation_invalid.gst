#[scoped(workspace_id)]
type Phase21CrossTenantPredicateWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21CrossTenantPredicateWorkspace as workspace;
        predicate workspace.workspace_id == cross_tenant_capability_from_host();
        cross_tenant cross_tenant_capability_from_host();
        terminal 73;
    };
}
