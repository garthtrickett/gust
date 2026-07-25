func main() int {
    mut first := phase13_composition_left(4);
    mut second := phase13_composition_right(first);
    second = second + 5;
    return second;
}

func phase13_composition_left(value: int) int {
    return phase13_composition_leaf(value, 2);
}

func phase13_composition_right(value: int) int {
    return phase13_composition_leaf(value, 3);
}

func phase13_composition_leaf(value: int, delta: int) int {
    return value + delta;
}