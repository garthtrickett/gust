type Choice enum { Zero, One }
func run(choice: Choice, q: *int) *int {
    mut p: *int;
    unsafe { p = 1 as *int; }
    match choice {
        Zero => { unsafe { p = (0 + 0) as *int; } }
        One => { p = q; }
    }
    return p;
}
func main() int { return 0; }
