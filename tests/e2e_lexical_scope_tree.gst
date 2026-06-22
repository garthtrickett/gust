type SharedConfig struct {
    compiler_flag: int
}
type Scope[ctx] struct {
    parent: Index[Scope[ctx], ctx],
    variables: std.HashMap[str, int, ctx],
    config: std.Rc[SharedConfig, ctx]
}

func lookup_variable(pool: *std.Pool[Scope[ctx], ctx], scope_idx: Index[Scope[ctx], ctx], name: str) int {
    mut curr := scope_idx;
    while curr != null {
        unsafe {
            mut lookup := (*pool)[curr].variables.Get(name);
            if lookup.Ok {
                return lookup.Val;
            }
            curr = (*pool)[curr].parent;
        }
    }
    return 0 - 1;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut pool: std.Pool[Scope[ctx], ctx] := std.PoolNew(ctx);
    mut rc_pool: std.Pool[std.RcNode[SharedConfig], ctx] := std.PoolNew(ctx);

    mut config: SharedConfig;
    config.compiler_flag = 42;

    mut rc_conf: std.Rc[SharedConfig, ctx] := std.RcNew(&rc_pool, config);

    mut root: Scope[ctx];
    root.parent = null;
    root.variables = std.HashMapNew(ctx);
    root.variables.Insert("global_var", 100);
    root.variables.Insert("shadowed_var", 1);
    root.config = rc_conf.Clone();

    mut root_idx := pool.Alloc(root);

    mut child: Scope[ctx];
    child.parent = root_idx;
    child.variables = std.HashMapNew(ctx);
    child.variables.Insert("local_var", 200);
    child.variables.Insert("shadowed_var", 2);
    child.config = rc_conf.Clone();

    mut child_idx := pool.Alloc(child);

    os.LogInt(lookup_variable(&pool, root_idx, "global_var"));
    os.LogInt(lookup_variable(&pool, root_idx, "shadowed_var"));
    os.LogInt(lookup_variable(&pool, root_idx, "local_var"));

    os.LogInt(lookup_variable(&pool, child_idx, "global_var"));
    os.LogInt(lookup_variable(&pool, child_idx, "shadowed_var"));
    os.LogInt(lookup_variable(&pool, child_idx, "local_var"));

    unsafe { 
        mut flag_ptr := child.config.Get();
        os.LogInt((*flag_ptr).compiler_flag);
    }

    child.config.Release();
    root.config.Release();
    rc_conf.Release();
}