func phase13_parameter_sum(base: int, left: int, right: int) int {
    return base + left + right;
}

func main() int {
    mut first := phase13_parameter_sum(1, 2, 3);
    mut second := phase13_parameter_sum(first, 4, 5);
    return second + 2;
}