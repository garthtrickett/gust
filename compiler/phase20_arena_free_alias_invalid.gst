// Patch 20.5: a local alias cannot revive a freed canonical identity.
func main() {
    mut destination := os.Arena.New();
    mut alias := destination;
    destination.Free();
    mut copied := std.Clone(alias, "freed");
}
