// Patch 20.5: scheduling a deferred Free does not invalidate early, but a
// second Free of the same identity would double-free at scope exit.
func main() {
    mut destination := os.Arena.New();
    defer destination.Free();
    destination.Free();
}
