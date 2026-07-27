// Future positive fixture: addressable local receives a compiler-owned stack slot.
func main() int {
    mut value: int := 11;
    mut pointer := &value;
    return *pointer;
}