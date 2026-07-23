func main() int {
    mut outer := 2;
    mut inner := 2;
    while outer > 0 {
        while inner > 0 {
            inner = inner - 1;
        }
        outer = outer - 1;
    }
    return outer;
}