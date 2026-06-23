func leak_ref() &int {
    mut x := 42;
    return &x;
}
func main() {}