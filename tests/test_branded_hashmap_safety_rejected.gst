type Node[ctx] struct { val: int }
func main() {
    mut ctx1 := os.Arena.New();
    defer ctx1.Free();
    mut ctx2 := os.Arena.New();
    defer ctx2.Free();
    mut map: HashMap[int, Index[Node, ctx1], ctx1] := os.HashMapNew(ctx1);
    mut n: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
    map.Insert(1, n);
    mut bad_ref_hashmap_brand := ctx2.get_ref(map[1]);
    bad_ref_hashmap_brand.val = 100;
}
