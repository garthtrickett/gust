// Future positive fixture: non-resource aggregate crosses a basic-block join.
type Phase14Pair struct {
    left: int,
    right: int
}
func main() int {
    mut value: Phase14Pair;
    if true {
        value.left = 3;
        value.right = 4;
    } else {
        value.left = 5;
        value.right = 6;
    }
    return value.left + value.right;
}