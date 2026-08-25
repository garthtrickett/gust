type Phase21Od8UnscopedLookup struct {
    lookup_id: int,
    value: int
}

#[scoped(workspace_id)]
type Phase21Od8ScopedJoin struct {
    workspace_id: int,
    value: int
}

func main() int {
    return query {
        root Phase21Od8UnscopedLookup as lookup;
        join Phase21Od8ScopedJoin as workspace predicate workspace.workspace_id == lookup.lookup_id;
        terminal 103;
    };
}
