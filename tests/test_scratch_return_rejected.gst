func test_leak() *byte {
    mut p := os.ScratchAlloc(10);
    return p;
}
func main() {}