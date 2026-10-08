unsafe func make_mayzero() *int { return (256 as byte) as *int; }
unsafe func unsafe_return() *int {
    mut ptr := make_mayzero(); return move (take ptr);
}
func main() int { return 0; }
