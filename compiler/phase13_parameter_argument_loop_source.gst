func phase13_parameter_sum(base: int, left: int, right: int) int {
    return base + left + right;
}

func main() int {
    mut remaining := 3;
    mut total := 1;
    while remaining > 0 {
        total = phase13_parameter_sum(total, 1, 1);
        remaining = remaining - 1;
    }
    return total;
}