import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Test set_init
    mut set1 := typechecker.set_init(ctx);
    
    // Test set_add
    typechecker.set_add(set1, "origin_a", ctx);
    typechecker.set_add(set1, "origin_b", ctx);

    // Test set_contains
    if typechecker.set_contains(set1, "origin_a", ctx) {
        os.LogStr("set1 has origin_a");
    } else {
        os.LogStr("set1 missing origin_a");
    }

    if typechecker.set_contains(set1, "origin_c", ctx) {
        os.LogStr("set1 has origin_c");
    } else {
        os.LogStr("set1 missing origin_c");
    }

    // Test set_union
    mut set2 := typechecker.set_init(ctx);
    typechecker.set_add(set2, "origin_c", ctx);
    typechecker.set_add(set2, "origin_d", ctx);

    typechecker.set_union(set1, set2, ctx);

    if typechecker.set_contains(set1, "origin_c", ctx) {
        os.LogStr("set1 now has origin_c");
    } else {
        os.LogStr("set1 still missing origin_c");
    }

    if typechecker.set_contains(set1, "origin_d", ctx) {
        os.LogStr("set1 now has origin_d");
    } else {
        os.LogStr("set1 still missing origin_d");
    }
}
