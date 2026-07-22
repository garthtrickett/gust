func main() int {
    mut gate := 1;
    mut left := 4;
    mut right := 6;
    mut total := left + right;
    left = left * 3;
    if gate > 0 {
        right = right + 2;
        total = left + right;
    } else {
        right = right + 2;
        total = left + right;
    }
    total = total - 1;
    left = total + gate;
    return left;
}