// Future positive fixture: captured environment closure call.
func main() int {
    mut offset := 3;
    mut add_offset := func(value: int) int {
        return value + offset;
    };
    return add_offset(4);
}