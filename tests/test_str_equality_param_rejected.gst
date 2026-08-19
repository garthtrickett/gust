// Compile-fail: the rejection must hold for parameters, not just locals.
func compare(left: str, right: str) int {
    if left == right {
        return 1;
    }
    return 0;
}
func main() {
    os.LogInt(compare("a", "b"));
}
