// Future positive fixture: declared-order struct field layout.
type Phase14LayoutPair struct {
    small: byte,
    wide: int
}
func main() int {
    mut value: Phase14LayoutPair;
    value.small = 2 as byte;
    value.wide = 9;
    return value.wide;
}