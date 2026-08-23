// A small application-shaped key/value workload for Stdlib Patch S1.6.
// It deliberately mixes explicit and inferred branded collection types while
// keeping one source file for every backend.
func record_setting(
    settings: &std.HashMap[str, int, ctx],
    destination: &Arena,
    key: str,
    value: int
) {
    mut owned_key := std.Clone(destination, key);
    settings.Insert(owned_key, value);
}

func setting_keys(
    settings: &std.HashMap[str, int, ctx],
    destination: &Arena
) std.Vector[str, destination] {
    return settings.Keys(destination);
}

func setting_value(settings: &std.HashMap[str, int, ctx], key: str) int {
    mut found := settings.Get(key);
    if found.Ok { return found.Val; }
    return 0;
}

func main() int {
    mut application_arena := os.Arena.New();
    defer application_arena.Free();

    // Explicit branded collection.
    mut settings: std.HashMap[str, int, application_arena] :=
        std.HashMapNew(application_arena);

    record_setting(&settings, &application_arena, "workers", 7);
    record_setting(&settings, &application_arena, "timeout", 11);
    record_setting(&settings, &application_arena, "retries", 13);

    // Inferred branded collection, returned from a helper that delegates to
    // the stdlib's HashMap.Keys helper.
    mut keys := setting_keys(&settings, &application_arena);

    // A second explicit collection keeps ordinary Vector construction and
    // cloned string storage in the same workload.
    mut requested: std.Vector[str, application_arena] :=
        std.VectorNew(application_arena);
    requested.Push(std.Clone(application_arena, "workers"));
    requested.Push(std.Clone(&application_arena, "timeout"));

    mut total := setting_value(&settings, "workers");
    total = total + setting_value(&settings, "timeout");
    total = total + setting_value(&settings, "retries");
    total = total + len(keys);
    total = total + len(requested);

    if total != 36 { return 1; }
    return 76;
}
