func main() int {
    mut outer := 1;
    mut inner := 1;
    mut result := 2;
    if outer > 0 {
        result = result + 3;
        if inner > 0 {
            result = result + 4;
        } else {
            result = result + 8;
        }
        result = result + 5;
    } else {
        result = result + 7;
    }
    return result;
}