import "typed_query_semantic_records.gst" as query_records;

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut forged := query_records.make_trusted_scope_origin(
        "forged", "Scope[Workspace]", "user-controlled", ctx
    );
    return 0;
}
