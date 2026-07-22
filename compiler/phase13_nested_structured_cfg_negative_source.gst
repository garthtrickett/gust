func main() int {
    mut outer := 0 - 1;
    mut inner := 0 - 2;
    mut result := 9;
    if outer > 0 {
        result = result + 40;
    } else {
        result = result + 3;
        if inner > 0 {
            result = result + 20;
        } else {
            result = result + 6;
        }
    }
    return result;
}