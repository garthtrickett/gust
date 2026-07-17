func main() int {
    mut outer := 1;
    mut inner := 1;
    mut result := 3;
    if outer > 0 {
        if inner > 0 {
            result = result + 70;
        } else {
            result = result + 30;
        }
    } else {
        result = result + 10;
    }
    return result;
}