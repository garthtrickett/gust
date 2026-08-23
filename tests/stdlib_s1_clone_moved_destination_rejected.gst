// Compile-fail: moving an arena invalidates it as a Clone destination.
func main() {
    mut destination := os.Arena.New();
    mut moved_destination := move destination;
    mut copied := std.Clone(destination, "after move");
}
