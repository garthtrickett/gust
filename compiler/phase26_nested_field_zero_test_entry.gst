import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_statement(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func check_nested_flow(write: str, followup: str, expected_rejection: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut raw_type := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut inner_type := typechecker.make_type_struct("Inner", "", ctx);
    mut outer_type := typechecker.make_type_struct("Outer", "", ctx);
    mut inner_layout: typechecker.StructLayout[ctx];
    inner_layout.brand = empty[Index[str, ctx]];
    inner_layout.fields = std.HashMapNew(ctx);
    inner_layout.fields.Insert("ptr", raw_type);
    typechecker.env_register_struct(&env, "Inner", inner_layout, ctx);
    mut outer_layout: typechecker.StructLayout[ctx];
    outer_layout.brand = empty[Index[str, ctx]];
    outer_layout.fields = std.HashMapNew(ctx);
    outer_layout.fields.Insert("inner", inner_type);
    typechecker.env_register_struct(&env, "Outer", outer_layout, ctx);
    typechecker.scope_insert(scope, "outer", outer_type, ctx);

    mut void_type: ast.Type[ctx];
    unsafe { void_type.tag = 3; }
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.return_type = void_type;
    sig.return_origins = typechecker.set_init(ctx);
    sig.param_names.Push("ptr");
    sig.params.Push(raw_type);
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    env.in_unsafe_block = 1;

    mut assignment := parse_statement(write, ctx);
    typechecker.check_statement(assignment, &env, scope, ctx);
    if len(followup) > 0 {
        mut second := parse_statement(followup, ctx);
        typechecker.check_statement(second, &env, scope, ctx);
    }
    if len(env.errors) != 0 {
        os.LogStr("Error: nested field write failed before safe boundary");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    mut call := parse_statement("accept_raw(outer.inner.ptr);", ctx);
    typechecker.check_statement(call, &env, scope, ctx);
    if expected_rejection == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: known-zero nested field crossed safe call");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: nonzero or unproven nested field changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_nested_flow("outer.inner.ptr = (0 + 0) as *int;", "", 1, ctx);
    check_nested_flow("outer.inner.ptr = 1 as *int;", "", 0, ctx);
    check_nested_flow("outer.inner.ptr = (1 * 1) as *int;", "", 0, ctx);
    check_nested_flow("outer.inner.ptr = (0 + 0) as *int;", "outer.inner.ptr = 1 as *int;", 0, ctx);
    check_nested_flow("outer.inner.ptr = 1 as *int;", "if 1 { outer.inner.ptr = (0 + 0) as *int; }", 1, ctx);
    check_nested_flow("outer.inner.ptr = 1 as *int;", "while 0 { outer.inner.ptr = (0 + 0) as *int; }", 1, ctx);
    check_nested_flow("outer.inner.ptr = (0 + 0) as *int;", "outer.inner = outer.inner;", 1, ctx);
    os.LogStr("SUCCESS: nested local by-value field zero evidence and exclusions verified");
    return 0;
}
