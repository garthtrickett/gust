// Stdlib S1.5 explicit half. The inferred half differs only by local type
// annotations; both must produce byte-identical MIR-to-C output and behaviour.
type S1CloneArenaHolder struct {
    destination: Arena
}

type S1CloneText[ctx] struct {
    value: str
}

func clone_text(destination: &Arena, input: str) str {
    return std.Clone(destination, input);
}

func clone_record(destination: &Arena, input: str) S1CloneText[destination] {
    mut result: S1CloneText[destination];
    result.value = std.Clone(destination, input);
    return result;
}

func main() int {
    mut local_arena := os.Arena.New();
    defer local_arena.Free();

    mut holder: S1CloneArenaHolder;
    holder.destination = os.Arena.New();
    defer holder.destination.Free();

    mut owned_text: str := std.Clone(local_arena, "owned");
    mut referenced_text: str := std.Clone(&local_arena, "reference");
    mut helper_text: str := clone_text(&local_arena, "helper");
    mut field_text: str := std.Clone(holder.destination, "field");
    mut field_reference_text: str := std.Clone(&holder.destination, "field-ref");
    mut record: S1CloneText[local_arena] := clone_record(&local_arena, "record");

    if std.str_eq(owned_text, "owned") == 0 { return 1; }
    if std.str_eq(referenced_text, "reference") == 0 { return 2; }
    if std.str_eq(helper_text, "helper") == 0 { return 3; }
    if std.str_eq(field_text, "field") == 0 { return 4; }
    if std.str_eq(field_reference_text, "field-ref") == 0 { return 5; }
    if std.str_eq(record.value, "record") == 0 { return 6; }

    mut total: int := len(owned_text);
    total = total + len(referenced_text);
    total = total + len(helper_text);
    total = total + len(field_text);
    total = total + len(field_reference_text);
    total = total + len(record.value);
    if total != 40 { return 7; }
    return 65;
}
