#[scoped(workspace_id)]
type Phase21ScopedJoinRoot struct {
    workspace_id: int,
    value: int
}

type Phase21UnscopedLookup struct {
    lookup_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21ScopedJoinRoot as workspace;
        predicate workspace.workspace_id == trusted_scope_from_context("workspace_id");
        join Phase21UnscopedLookup as lookup predicate lookup.lookup_id == workspace.value;
        terminal 54;
    };
}
