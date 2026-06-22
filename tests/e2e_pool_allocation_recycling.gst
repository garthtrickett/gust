type Node struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);

    mut n1: Node;
    n1.val = 111;
    mut idx1 := pool.Alloc(n1);

    mut n2: Node;
    n2.val = 222;
    mut idx2 := pool.Alloc(n2);

    mut n3: Node;
    n3.val = 333;
    mut idx3 := pool.Alloc(n3);

    // Log first three indices and values to verify
    os.LogInt(idx1);
    os.LogInt(pool[idx1].val);
    os.LogInt(idx2);
    os.LogInt(pool[idx2].val);
    os.LogInt(idx3);
    os.LogInt(pool[idx3].val);

    // Free n1 and n3
    pool.Free(idx1);
    pool.Free(idx3);

    // Allocate a fourth node
    mut n4: Node;
    n4.val = 444;
    mut idx4 := pool.Alloc(n4);

    // idx4 should reuse index 2 (which was idx3) because standard stack-based freelist reclaims the last freed slot!
    os.LogInt(idx4);
    os.LogInt(pool[idx4].val);
}