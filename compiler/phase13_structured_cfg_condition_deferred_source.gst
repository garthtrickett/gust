func main() int {
    mut left := 4;
    mut right := 4;
    mut result := 0;
    if left == right {
        result = result + 1;
    } else {
        result = result + 2;
    }
    if result == left {
        result = result + 3;
    } else {
        result = result + 4;
    }
    return result;
}