func main() int {
    mut gate := 1;
    mut left := 3;
    mut right := 5;
    mut total := left + right;
    left = left * 4;
    if gate > 0 {
        right = right + 2;
        total = left + right;
    } else {
        right = right + 2;
        total = left + right;
    }
    total = total - 2;
    left = total + gate;
    return left;
}