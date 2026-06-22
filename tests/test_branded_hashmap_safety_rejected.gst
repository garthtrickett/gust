type Node[ctx] struct { val: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut map: HashMap[int, Index[Node, ctx1], ctx1] := os.HashMapNew(ctx1);
    mut n: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
    map.Insert(1, n);
    ctx2[map[1]].val = 100;
}