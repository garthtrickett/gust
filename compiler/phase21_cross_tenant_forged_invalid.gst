#[scoped(workspace_id)]
type Phase21CrossTenantForgedWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut forged_capability := 1;
    return query {
        root Phase21CrossTenantForgedWorkspace as workspace;
        cross_tenant forged_capability;
        terminal 73;
    };
}
