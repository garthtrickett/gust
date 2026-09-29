type Choice enum { Zero, One }
func accept_raw(p: *int) {}
func run(choice: Choice, q: *int) {
    mut p: *int;
    unsafe { p = 1 as *int; }
    match choice {
        Zero => { unsafe { p = (0 + 0) as *int; } }
        One => { p = q; }
    }
    unsafe { accept_raw(p); }
}
func main() int { return 0; }
