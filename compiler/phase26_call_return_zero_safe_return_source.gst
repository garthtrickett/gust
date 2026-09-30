unsafe func make_zero() *int { return empty[*int]; }
func relay_zero() *int {
    unsafe { return make_zero(); }
}
func main() int { return 0; }
