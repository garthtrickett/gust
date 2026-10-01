func relay_zero() *int {
    unsafe { return move make_zero(); }
}
unsafe func make_zero() *int { return empty[*int]; }
func main() int { return 0; }
