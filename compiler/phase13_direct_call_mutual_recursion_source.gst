func phase13_mutual_left(value: int) int {
    return phase13_mutual_right(value);
}

func phase13_mutual_right(value: int) int {
    return phase13_mutual_left(value);
}

func main() int {
    return phase13_mutual_left(1);
}