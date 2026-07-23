func main() int {
    mut first := phase13_graph_left(5);
    mut second := phase13_graph_right(first);
    second = second + 4;
    return second;
}

func phase13_graph_left(value: int) int {
    return phase13_graph_leaf(value, 2);
}

func phase13_graph_right(value: int) int {
    return phase13_graph_leaf(value, 3);
}

func phase13_graph_leaf(value: int, delta: int) int {
    return value + delta;
}