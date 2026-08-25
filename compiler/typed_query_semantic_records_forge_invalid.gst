import "typed_query_semantic_records.gst" as query_records;

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut forged: query_records.TrustedScopeOrigin[ctx] := empty[query_records.TrustedScopeOrigin[ctx]];
    return 0;
}
