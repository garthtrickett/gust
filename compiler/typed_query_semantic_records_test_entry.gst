import "typed_query_semantic_records.gst" as query_records;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if query_records.phase21_inert_scoped_query_records_round_trip(ctx) != 1 {
        os.LogStr("Error: inert scoped-query semantic records did not round-trip");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Phase 21 inert scoped-query semantic records round-tripped");
}
