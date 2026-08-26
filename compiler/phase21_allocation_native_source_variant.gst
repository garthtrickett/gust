type RenamedPhase21Cell struct {
    payload: int
}

func main() {
    mut scratch := os.Arena.New();
    defer scratch.Free();
    mut slot: Index[RenamedPhase21Cell, scratch] := os.ArenaAlloc(scratch);
    mut cell: RenamedPhase21Cell;
    cell.payload = 73;
    scratch.Set(slot, cell);
    os.LogInt(scratch[slot].payload);
}
