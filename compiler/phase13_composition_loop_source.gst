func phase13_composition_loop_sum(base: int, left: int, right: int) int {
    return base + left + right;
}

func main() int {
    mut remaining := 4;
    mut total := 2;
    while remaining > 0 {
        total = phase13_composition_loop_sum(total, 2, 1);
        remaining = remaining - 1;
    }
    return total;
}