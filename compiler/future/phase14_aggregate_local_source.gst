// Future positive fixture: aggregate local declaration, assignment, and read.
type Phase14AggregateLocal struct {
    left: int,
    right: int
}

func main() int {
    mut value: Phase14AggregateLocal;
    value.left = 4;
    value.right = 5;
    return value.left + value.right;
}