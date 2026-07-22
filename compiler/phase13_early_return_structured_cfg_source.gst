func main() int {
    mut outer := 1;
    mut inner := 1;
    mut result := 7;
    if outer > 0 {
        result = result + 5;
        if inner > 0 {
            return result;
        } else {
            result = result + 20;
        }
    } else {
        result = result + 2;
    }
    result = result + 1;
    return result;
}