func main() int {
    mut first := 1;
    mut second := 1;
    mut result := 1;
    if first > 0 {
        result = result + 10;
    } else {
        result = result + 2;
    }
    result = result + 1;
    if second > 0 {
        result = result + 20;
    } else {
        result = result + 4;
    }
    return result;
}