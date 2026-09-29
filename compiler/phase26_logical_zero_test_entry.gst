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

func check_cell(op: int, left: int, right: int, expected: int) {
    mut observed := typechecker.phase26_zero_logical_and(left, right);
    if op == 1 { observed = typechecker.phase26_zero_logical_or(left, right); }
    if observed != expected {
        os.LogStr("Error: logical zero-evidence transfer table drifted");
        os.LogInt(op);
        os.LogInt(left);
        os.LogInt(right);
        os.LogInt(observed);
        os.Exit(1);
    }
}

func check_row(op: int, left: int, zero: int, may: int, nonzero: int, unknown: int) {
    check_cell(op, left, typechecker.phase26_zero_yes(), zero);
    check_cell(op, left, typechecker.phase26_zero_may(), may);
    check_cell(op, left, typechecker.phase26_zero_no(), nonzero);
    check_cell(op, left, typechecker.phase26_zero_unknown(), unknown);
}

func check_tables() {
    mut z := typechecker.phase26_zero_yes();
    mut m := typechecker.phase26_zero_may();
    mut n := typechecker.phase26_zero_no();
    mut u := typechecker.phase26_zero_unknown();
    // Columns are Zero, MayZero, Nonzero, Unknown. Both tables are symmetric.
    check_row(0, z, z, z, z, z);
    check_row(0, m, z, m, m, m);
    check_row(0, n, z, m, n, u);
    check_row(0, u, z, m, u, u);
    check_row(1, z, z, m, n, u);
    check_row(1, m, m, m, n, u);
    check_row(1, n, n, n, n, n);
    check_row(1, u, u, u, n, u);
}

func check_state(src: str, expected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    env.in_unsafe_block = 1;
    mut expr := parse_expression(src, ctx);
    typechecker.check_expression(expr, &env, scope, ctx);
    mut state := typechecker.phase26_zero_expression(expr, &env, ctx);
    if len(env.errors) != 0 || state != expected {
        os.LogStr("Error: typechecked logical expression zero evidence drifted");
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
            os.LogStr("Error: logical zero safe boundary was not rejected");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: logical control changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_tables();
    check_state("false && true", typechecker.phase26_zero_yes(), ctx);
    check_state("true && true", typechecker.phase26_zero_no(), ctx);
    check_state("false || true", typechecker.phase26_zero_no(), ctx);
    check_state("false || false", typechecker.phase26_zero_yes(), ctx);
    check_state("0 && 1", typechecker.phase26_zero_yes(), ctx);
    check_state("1 || 0", typechecker.phase26_zero_no(), ctx);
    check_state("(true && false) as *int", typechecker.phase26_zero_yes(), ctx);
    check_boundary("accept_raw((false && true) as *int);", 1, 0, 1, ctx);
    check_boundary("accept_raw((false || true) as *int);", 1, 0, 0, ctx);
    check_boundary("accept_raw((false && true) as *int);", 1, 1, 0, ctx);
    check_boundary("func safe_zero() *int { unsafe { return (true && false) as *int; } }", 0, 0, 1, ctx);
    check_boundary("func safe_nonzero() *int { unsafe { return (false || true) as *int; } }", 0, 0, 0, ctx);
    os.LogStr("SUCCESS: typechecked logical AND/OR zero-evidence tables and boundaries verified");
}
