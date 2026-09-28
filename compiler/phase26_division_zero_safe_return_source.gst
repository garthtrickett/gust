func safe_zero_sub() *int {
    unsafe { return (0 / 1) as *int; }
}
func main() int { return 0; }
