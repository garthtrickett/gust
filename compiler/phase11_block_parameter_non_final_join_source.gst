func main() int {
    mut left := 3;
    mut right := 4;
    if left > 0 {
        left = left + 10;
        right = right + 20;
    } else {
        left = left + 1;
        right = right + 2;
    }
    if right > 0 {
        left = left + 1;
    } else {
        left = left + 2;
    }
    return left;
}