import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_expression(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func parse_statement(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func check_cell(op: str, left: int, right: int, expected: int) {
    mut observed := typechecker.phase26_zero_relational(op, left, right);
    if observed != expected {
        os.LogStr("Error: relational zero-evidence transfer table drifted");
        os.LogStr(op);
        os.LogInt(left);
        os.LogInt(right);
        os.LogInt(observed);
        os.Exit(1);
    }
}

func check_row(op: str, left: int, zero: int, may: int, nonzero: int, unknown: int) {
    check_cell(op, left, typechecker.phase26_zero_yes(), zero);
    check_cell(op, left, typechecker.phase26_zero_may(), may);
    check_cell(op, left, typechecker.phase26_zero_no(), nonzero);
    check_cell(op, left, typechecker.phase26_zero_unknown(), unknown);
}

func check_operator(op: str, zero_zero: int) {
    mut z := typechecker.phase26_zero_yes();
    mut u := typechecker.phase26_zero_unknown();
    check_row(op, z, zero_zero, u, u, u);
    check_row(op, typechecker.phase26_zero_may(), u, u, u, u);
    check_row(op, typechecker.phase26_zero_no(), u, u, u, u);
    check_row(op, u, u, u, u, u);
}

func check_tables() {
    check_operator("<", typechecker.phase26_zero_yes());
    check_operator("<=", typechecker.phase26_zero_no());
    check_operator(">", typechecker.phase26_zero_yes());
    check_operator(">=", typechecker.phase26_zero_no());
}

func check_state(src: str, expected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    env.in_unsafe_block = 1;
    mut expr := parse_expression(src, ctx);
    typechecker.check_expression(expr, &env, scope, ctx);
    mut state := typechecker.phase26_zero_expression(expr, &env, ctx);
    if len(env.errors) != 0 || state != expected {
        os.LogStr("Error: typechecked relational expression zero evidence drifted");
        os.LogStr(src);
        os.LogInt(state);
        if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
        os.Exit(1);
    }
}

func check_boundary(src: str, is_call: int, unsafe_callee: int, rejected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    if is_call == 1 {
        mut sig: typechecker.FunctionSignature[ctx];
        typechecker.init_function_signature_ffi_defaults(&sig);
        sig.param_names = std.VectorNew(ctx);
        sig.params = std.VectorNew(ctx);
        mut void_type: ast.Type[ctx];
        unsafe { void_type.tag = 3; }
        sig.return_type = void_type;
        sig.return_origins = typechecker.set_init(ctx);
        sig.is_unsafe = unsafe_callee;
        sig.param_names.Push("ptr");
        sig.params.Push(typechecker.make_type_pointer(typechecker.make_type_int(), ctx));
        typechecker.env_register_function(&env, "accept_raw", sig, ctx);
        env.in_unsafe_block = 1;
    }
    typechecker.check_statement(parse_statement(src, ctx), &env, scope, ctx);
    if rejected == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: relational zero safe boundary was not rejected");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: relational control changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_tables();
    check_state("0 < 0", typechecker.phase26_zero_yes(), ctx);
    check_state("0 <= 0", typechecker.phase26_zero_no(), ctx);
    check_state("0 > 0", typechecker.phase26_zero_yes(), ctx);
    check_state("0 >= 0", typechecker.phase26_zero_no(), ctx);
    check_state("1 < 0", typechecker.phase26_zero_unknown(), ctx);
    check_state("(0 < 0) as *int", typechecker.phase26_zero_yes(), ctx);
    check_boundary("accept_raw((0 < 0) as *int);", 1, 0, 1, ctx);
    check_boundary("accept_raw((0 <= 0) as *int);", 1, 0, 0, ctx);
    check_boundary("accept_raw((0 < 0) as *int);", 1, 1, 0, ctx);
    check_boundary("func safe_zero() *int { unsafe { return (0 > 0) as *int; } }", 0, 0, 1, ctx);
    check_boundary("func safe_nonzero() *int { unsafe { return (0 >= 0) as *int; } }", 0, 0, 0, ctx);
    os.LogStr("SUCCESS: typechecked relational zero-evidence tables and boundaries verified");
}
