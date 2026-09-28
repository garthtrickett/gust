func safe_zero_sub() *int {
    unsafe { return (0 - 0) as *int; }
}
func main() int { return 0; }
