func phase13_identity(value: int) int {
    return value;
}

func main() int {
    mut before := 5;
    before = before + 3;
    mut after := phase13_identity(before);
    after = after + 4;
    return after;
}