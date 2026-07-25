type Phase13AggregateLocal struct {
    left: int,
    right: int
}

func main() int {
    mut value: Phase13AggregateLocal;
    value.left = 2;
    value.right = 3;
    return value.left + value.right;
}