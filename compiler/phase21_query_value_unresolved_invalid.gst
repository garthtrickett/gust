#[scoped(workspace_id)]
type Phase21QueryValueRoot struct {
    workspace_id: int,
    value: int
}

func main() int {
    mut unresolved_query_value := query {
        root Phase21QueryValueRoot as workspace;
        terminal 64;
    };
    mut aliased_query_value := unresolved_query_value;
    return aliased_query_value;
}
