func main() {
    mut x := 42;
    unsafe {
        mut y := *x;
    }
}
