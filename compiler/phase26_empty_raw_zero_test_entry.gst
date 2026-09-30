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

func check_state(src: str, expected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    env.in_unsafe_block = 1;
    mut expr := parse_expression(src, ctx);
    typechecker.check_expression(expr, &env, scope, ctx);
    mut state := typechecker.phase26_zero_expression(expr, &env, ctx);
    if len(env.errors) != 0 || state != expected {
        os.LogStr("Error: canonical Empty raw-pointer zero evidence drifted");
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
            os.LogStr("Error: Empty raw pointer crossed a safe boundary");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: Empty raw-pointer control changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_state("empty[*int]", typechecker.phase26_zero_yes(), ctx);
    check_state("empty[int]", typechecker.phase26_zero_unknown(), ctx);
    check_state("empty[bool]", typechecker.phase26_zero_unknown(), ctx);
    check_boundary("accept_raw(empty[*int]);", 1, 0, 1, ctx);
    check_boundary("accept_raw(1 as *int);", 1, 0, 0, ctx);
    check_boundary("accept_raw(empty[*int]);", 1, 1, 0, ctx);
    check_boundary("func safe_zero() *int { unsafe { return empty[*int]; } }", 0, 0, 1, ctx);
    check_boundary("func safe_unknown(ptr: *int) *int { return ptr; }", 0, 0, 0, ctx);
    check_boundary("unsafe func unsafe_zero() *int { return empty[*int]; }", 0, 0, 0, ctx);
    os.LogStr("SUCCESS: canonical Empty raw-pointer zero evidence and safe-boundary controls verified");
}
