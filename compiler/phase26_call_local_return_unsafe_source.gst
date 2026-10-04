unsafe func make_mayzero() *int { return (256 as byte) as *int; }
unsafe func relay_mayzero() *int {
    mut ptr := make_mayzero(); return ptr;
}
func main() int { return 0; }
