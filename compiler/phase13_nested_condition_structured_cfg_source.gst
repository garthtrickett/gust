func main() int {
    mut left := 5;
    mut right := 3;
    mut result := 2;
    if (left + right) > 0 {
        result = result + 10;
        if ((left * 2) - right) > 0 {
            result = result + 20;
        } else {
            result = result + 4;
        }
    } else {
        result = result + 1;
    }
    return result;
}