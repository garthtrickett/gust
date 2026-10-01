func relay_zero() *int {
    unsafe { return move take make_zero(); }
}
func main() int { return 0; }
unsafe func make_zero() *int { return empty[*int]; }
