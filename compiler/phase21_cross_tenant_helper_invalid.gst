#[scoped(workspace_id)]
type Phase21CrossTenantHelperWorkspace struct {
    workspace_id: int,
    value: int
}

func ordinary_capability_helper() int {
    return 1;
}

func main() int {
    return query {
        root Phase21CrossTenantHelperWorkspace as workspace;
        cross_tenant ordinary_capability_helper();
        terminal 74;
    };
}
