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

func check_take_flow(value: str, through_assignment: int, unsafe_callee: int, expect_rejection: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut raw_type := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    typechecker.scope_insert(scope, "p", raw_type, ctx);
    typechecker.scope_insert(scope, "q", raw_type, ctx);

    mut void_type: ast.Type[ctx];
    unsafe { void_type.tag = 3; }
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.param_names.Push("p");
    sig.params.Push(raw_type);
    sig.return_type = void_type;
    sig.return_origins = typechecker.set_init(ctx);
    sig.is_unsafe = unsafe_callee;
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    env.in_unsafe_block = 1;

    typechecker.check_statement(parse_statement(value, ctx), &env, scope, ctx);
    if len(env.errors) != 0 {
        os.LogStr("Error: setup failed before take transfer");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    if through_assignment == 1 {
        typechecker.check_statement(parse_statement("q = take p;", ctx), &env, scope, ctx);
        typechecker.check_statement(parse_statement("accept_raw(q);", ctx), &env, scope, ctx);
    } else {
        typechecker.check_statement(parse_statement("accept_raw(take p);", ctx), &env, scope, ctx);
    }
    if expect_rejection == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: known zero passed through take into a safe call");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: nonzero, unknown, or unsafe take control changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_take_flow("p = (0 + 0) as *int;", 0, 0, 1, ctx);
    check_take_flow("p = (0 + 0) as *int;", 1, 0, 1, ctx);
    check_take_flow("if 1 { p = (0 + 0) as *int; }", 0, 0, 1, ctx);
    check_take_flow("if 1 { p = (0 + 0) as *int; }", 1, 0, 1, ctx);
    check_take_flow("p = 1 as *int;", 0, 0, 0, ctx);
    check_take_flow("p = 1 as *int;", 1, 0, 0, ctx);
    check_take_flow("p = q;", 0, 0, 0, ctx);
    check_take_flow("p = q;", 1, 0, 0, ctx);
    check_take_flow("p = (0 + 0) as *int;", 0, 1, 0, ctx);
    check_take_flow("p = (0 + 0) as *int;", 1, 1, 0, ctx);
    os.LogStr("SUCCESS: take preserves known-zero evidence and existing controls");
    return 0;
}
