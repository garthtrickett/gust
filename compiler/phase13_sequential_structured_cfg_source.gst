func main() int {
    mut first := 1;
    mut second := 0 - 1;
    mut result := 4;
    if first > 0 {
        result = result + 8;
    } else {
        result = result + 2;
    }
    result = result + 1;
    if second > 0 {
        result = result + 32;
    } else {
        result = result + 16;
    }
    return result;
}