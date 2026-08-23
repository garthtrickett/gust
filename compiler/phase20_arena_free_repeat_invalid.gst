// Patch 20.5: a repeated immediate Free is rejected.
func main() {
    mut destination := os.Arena.New();
    destination.Free();
    destination.Free();
}
