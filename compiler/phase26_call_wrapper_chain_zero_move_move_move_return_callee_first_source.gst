unsafe func make_zero() *int { return empty[*int]; }
func relay_zero() *int {
    unsafe { return move move move make_zero(); }
}
func main() int { return 0; }
