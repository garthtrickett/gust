func main() int {
    mut left := 1;
    mut right := 1;
    mut result := 0;
    if left > 0 && right > 0 {
        result = result + 1;
    } else {
        result = result + 2;
    }
    return result;
}