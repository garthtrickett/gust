func main() int {
    mut counter := 4;
    while counter > 0 {
        if counter > 2 {
            return counter;
        } else {
            counter = counter - 1;
        }
    }
    return counter;
}