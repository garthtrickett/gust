// Future positive fixture: nested reducible loops with independent carried state.
func main() int {
    mut outer := 2;
    while outer > 0 {
        mut inner := 2;
        while inner > 0 {
            inner = inner - 1;
        }
        outer = outer - 1;
    }
    return outer;
}