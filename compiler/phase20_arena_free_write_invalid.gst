// Patch 20.5: write through a freed canonical identity is rejected.
func main() {
    mut destination := os.Arena.New();
    mut value: Index[int, destination] := os.ArenaAlloc(destination);
    destination.Free();
    destination.Set(value, 9);
}
