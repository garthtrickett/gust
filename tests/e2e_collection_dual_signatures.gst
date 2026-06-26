type DualSigNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Arena.get_ref baseline: explicit branded arena borrowing remains supported.
    mut node_idx: Index[DualSigNode, ctx] := os.ArenaAlloc(ctx);
    ctx[node_idx].val = 10;
    mut node_ref := ctx.get_ref(node_idx);
    node_ref.val = node_ref.val + 1;
    os.LogInt(ctx[node_idx].val);

    // Vector.GetRef baseline: explicit vector borrowing remains supported.
    mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec.Push(20);
    vec.Push(30);
    mut vec_ref := vec.GetRef(0);
    os.LogInt(*vec_ref);
    *vec_ref = *vec_ref + 5;

    // Vector.get_opt baseline: additive Option lookup remains supported.
    mut vec_hit := vec.get_opt(0);
    match vec_hit {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }

    mut vec_miss := vec.get_opt(99);
    match vec_miss {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }

    // HashMap.Get baseline: legacy lookup wrapper remains supported.
    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(7, 100);
    map.Insert(8, 200);

    mut legacy_hit := map.Get(7);
    if legacy_hit.Ok {
        os.LogInt(legacy_hit.Val);
    } else {
        os.LogStr("legacy miss");
    }

    mut legacy_miss := map.Get(99);
    if legacy_miss.Ok {
        os.LogInt(legacy_miss.Val);
    } else {
        os.LogStr("legacy miss");
    }

    // HashMap.get_opt baseline: additive Option lookup coexists with legacy Get.
    mut opt_hit := map.get_opt(8);
    match opt_hit {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }

    mut opt_miss := map.get_opt(123);
    match opt_miss {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }
}