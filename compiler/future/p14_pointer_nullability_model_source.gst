// Future positive fixture: typed pointer and nullable pointer representation.
func main() int {
    mut value: int := 7;
    mut pointer := &value;
    if pointer != null {
        return 7;
    }
    return 0;
}