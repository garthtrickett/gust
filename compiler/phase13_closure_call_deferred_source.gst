func main() int {
    mut offset := 2;
    mut add_offset := func(value: int) int {
        return value + offset;
    };
    return add_offset(5);
}