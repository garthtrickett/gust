unsafe func make_nonzero() *int { return 1 as *int; }
func relay_nonzero() *int {
    unsafe { mut ptr := make_nonzero(); mut alias := ptr; return (alias as *int) as *int; }
}
func main() int { return 0; }
