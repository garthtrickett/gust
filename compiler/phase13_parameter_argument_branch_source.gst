func phase13_parameter_sum(base: int, left: int, right: int) int {
    return base + left + right;
}

func main() int {
    mut called := phase13_parameter_sum(19, 20, 3);
    if called > 0 {
        return called;
    }
    return 83;
}