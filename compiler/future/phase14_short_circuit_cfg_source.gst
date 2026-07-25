// Future positive fixture: expression-level short-circuit CFG.
func main() int {
    mut left := 1;
    mut right := 1;
    if left > 0 && right > 0 {
        return 1;
    }
    return 0;
}