func main() int {
    mut outer := 1;
    mut inner := 2;
    mut result := 5;
    if outer > 0 {
        result = result + 10;
        if inner > 0 {
            result = result + 20;
        } else {
            result = result + 4;
        }
        result = result + 1;
    } else {
        result = result + 2;
    }
    return result;
}