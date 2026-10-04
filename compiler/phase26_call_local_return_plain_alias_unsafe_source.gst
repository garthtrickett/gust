unsafe func make_mayzero() *int { return (256 as byte) as *int; }
unsafe func relay_mayzero() *int {
    mut ptr := make_mayzero(); mut alias := ptr; return alias;
}
func main() int { return 0; }
