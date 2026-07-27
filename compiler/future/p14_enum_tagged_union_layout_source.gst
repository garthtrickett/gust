// Future positive fixture: explicit tag and payload layout.
type Phase14Choice enum {
    Empty,
    Value(int)
}
func main() int {
    mut choice := Phase14Choice.Value(12);
    match choice {
        Phase14Choice.Empty => return 0,
        Phase14Choice.Value(value) => return value
    }
}