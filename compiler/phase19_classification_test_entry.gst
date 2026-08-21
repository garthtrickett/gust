import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func phase19_require(value: int, message: str) {
    if value != 1 {
        os.LogStr(message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut brand_t := typechecker.make_type_struct("scratch", "", ctx);
    mut int_t := typechecker.make_type_int();

    mut vector_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    vector_args.Push(int_t);
    vector_args.Push(brand_t);
    mut vector_result := typechecker.monomorphize(&env, "std.Vector", vector_args, ctx);
    mut vector_t: ast.Type[ctx];
    match vector_result {
        Ok { val } => { unsafe { vector_t = *val; } }
        Err { error } => { os.LogStr("vector monomorphization failed"); os.Exit(1); }
    }
    mut vector_classification := typechecker.typechecker_classify_type(vector_t, typechecker.typechecker_classification_vector(), &env, ctx);
    phase19_require(vector_classification, "resolved Vector was not registry-classified");

    mut map_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    map_args.Push(int_t);
    map_args.Push(int_t);
    map_args.Push(brand_t);
    mut map_result := typechecker.monomorphize(&env, "std.HashMap", map_args, ctx);
    mut map_t: ast.Type[ctx];
    match map_result {
        Ok { val } => { unsafe { map_t = *val; } }
        Err { error } => { os.LogStr("hashmap monomorphization failed"); os.Exit(1); }
    }
    mut map_classification := typechecker.typechecker_classify_type(map_t, typechecker.typechecker_classification_hashmap(), &env, ctx);
    phase19_require(map_classification, "resolved HashMap was not registry-classified");

    mut pool_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    pool_args.Push(int_t);
    pool_args.Push(brand_t);
    mut pool_result := typechecker.monomorphize(&env, "std.Pool", pool_args, ctx);
    mut pool_t: ast.Type[ctx];
    match pool_result {
        Ok { val } => { unsafe { pool_t = *val; } }
        Err { error } => { os.LogStr("pool monomorphization failed"); os.Exit(1); }
    }
    mut pool_classification := typechecker.typechecker_classify_type(pool_t, typechecker.typechecker_classification_pool(), &env, ctx);
    phase19_require(pool_classification, "resolved Pool was not registry-classified");

    mut arena_ref := typechecker.make_type_reference(typechecker.make_type_arena(), "scratch", ctx);
    mut arena_classification := typechecker.typechecker_classify_type(arena_ref, typechecker.typechecker_classification_arena(), &env, ctx);
    phase19_require(arena_classification, "Reference(Arena) was not classified as arena");
    if typechecker.typechecker_classify_type(arena_ref, typechecker.typechecker_classification_pointer(), &env, ctx) != 0 { os.LogStr("Reference(Arena) was also classified as an ordinary pointer"); os.Exit(1); }

    mut raw_int_ptr := typechecker.make_type_pointer(int_t, ctx);
    mut pointer_classification := typechecker.typechecker_classify_type(raw_int_ptr, typechecker.typechecker_classification_pointer(), &env, ctx);
    phase19_require(pointer_classification, "raw int pointer was not classified from its type");

    mut str_classification := typechecker.typechecker_classify_type(typechecker.make_type_str(), typechecker.typechecker_classification_slice(), &env, ctx);
    phase19_require(str_classification, "str was not classified as slice-like");

    mut fake_layout: typechecker.StructLayout[ctx];
    fake_layout.brand = empty[Index[str, ctx]];
    fake_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "Vector_Pretender", fake_layout, ctx);
    mut fake_t := typechecker.make_type_struct("Vector_Pretender", "", ctx);
    mut fake_classification := typechecker.typechecker_classify_type(fake_t, typechecker.typechecker_classification_vector(), &env, ctx);
    if fake_classification != 0 {
        os.LogStr("unregistered Vector-like spelling changed classification");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Phase 19 type-derived classification verified");
}
