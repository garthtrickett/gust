type Node[ctx] struct { val: int }
func update(ctx: &Arena, n: Index[Node, ctx]) {
    ctx[n].val = 100;
}
func main() {
    mut c := os.Arena.New();
    defer c.Free();
    mut n: Index[Node, c] := os.ArenaAlloc(c);
    update(c, n);
}