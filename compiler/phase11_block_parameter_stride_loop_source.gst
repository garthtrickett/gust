func main() int {
    mut counter := 5;
    mut total := 1;
    while counter > 0 {
        counter = counter - 2;
        total = total + 3;
    }
    return total;
}