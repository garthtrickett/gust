// Future positive fixture: loop-body branch plus early exit.
func main() int {
    mut counter := 4;
    while counter > 0 {
        if counter > 2 {
            counter = counter - 2;
        } else {
            return counter;
        }
    }
    return counter;
}