func phase13_composition_identity(value: int) int {
    return value;
}

func main() int {
    mut before := 4;
    before = before + 5;
    mut after := phase13_composition_identity(before);
    after = after + 6;
    return after;
}