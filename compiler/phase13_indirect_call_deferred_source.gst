func phase13_indirect_target(value: int) int {
    return value + 1;
}

func main() int {
    mut target := phase13_indirect_target;
    return target(4);
}