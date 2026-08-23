// Compile-fail: an immediately freed arena cannot be reused as a Clone
// destination.
func main() {
    mut destination := os.Arena.New();
    destination.Free();
    mut copied := std.Clone(destination, "after free");
}
