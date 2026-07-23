func phase13_parameter_sum(base: int, left: int, right: int) int {
    return base + left + right;
}

func main() int {
    mut called := phase13_parameter_sum(1, 2, 3);
    mut result := 0;
    if called > 0 {
        result = phase13_parameter_sum(called, 4, 2);
    } else {
        result = phase13_parameter_sum(1, called, 1);
    }
    return result;
}