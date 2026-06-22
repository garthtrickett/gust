type Node[ctx] struct { val: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut n1: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
    ctx1[n1].val = 42;
    mut n2: Index[Node, ctx2] := std.Clone(ctx2, n1);
    ctx2[n2].val = 100;
}