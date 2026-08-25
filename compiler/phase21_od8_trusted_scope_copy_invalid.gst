#[scoped(workspace_id)]
type Phase21Od8CopyWorkspace struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut copied_scope := trusted_scope_from_context("workspace_id");
    return query {
        root Phase21Od8CopyWorkspace as workspace;
        predicate workspace.workspace_id == copied_scope;
        terminal 105;
    };
}
