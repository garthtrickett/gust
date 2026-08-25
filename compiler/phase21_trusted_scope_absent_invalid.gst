#[scoped(workspace_id)]
type Phase21AbsentWorkspaceRow struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21AbsentWorkspaceRow as workspace;
        terminal 91;
    };
}
