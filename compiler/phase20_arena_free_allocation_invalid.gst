// Patch 20.5: allocation through a freed canonical identity is rejected.
func main() {
    mut destination := os.Arena.New();
    destination.Free();
    mut value := os.ArenaAlloc(destination);
}
