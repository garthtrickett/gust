func main() int {
    mut outer := 1;
    mut inner := 1;
    mut result := 7;
    if outer > 0 {
        if inner > 0 {
            result = result + 64;
        } else {
            result = result + 8;
        }
    } else {
        result = result + 2;
    }
    return result;
}