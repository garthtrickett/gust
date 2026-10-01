func relay_zero() *int {
    unsafe { return take make_zero(); }
}
unsafe func make_zero() *int { return empty[*int]; }
func main() int { return 0; }
