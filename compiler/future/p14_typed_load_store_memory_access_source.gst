// Future positive fixture: typed load and store use one compiler-owned access layout.
func main() int {
    mut value: int := 2;
    mut pointer := &value;
    *pointer = 13;
    return *pointer;
}