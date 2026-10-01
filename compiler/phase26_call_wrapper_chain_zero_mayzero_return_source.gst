func relay_mayzero() *int {
    unsafe { return move take move make_mayzero(); }
}
func main() int { return 0; }
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
