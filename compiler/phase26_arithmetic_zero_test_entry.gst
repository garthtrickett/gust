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

func check_call(src: str, unsafe_callee: int, expected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut raw_type := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut void_type: ast.Type[ctx];
    unsafe { void_type.tag = 3; }
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.return_type = void_type;
    sig.return_origins = typechecker.set_init(ctx);
    sig.is_unsafe = unsafe_callee;
    sig.param_names.Push("ptr");
    sig.params.Push(raw_type);
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    env.in_unsafe_block = 1;
    mut stmt := parse_statement(src, ctx);
    typechecker.check_statement(stmt, &env, scope, ctx);
    if expected == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: arithmetic zero crossed safe argument");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if expected == 2 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "Argument type mismatch") == 0 - 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") != 0 - 1 {
            os.LogStr("Error: argument type error precedence changed");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: accepted arithmetic raw-pointer argument changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func check_return(src: str, expected_rejection: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut stmt := parse_statement(src, ctx);
    typechecker.check_statement(stmt, &env, scope, ctx);
    if expected_rejection == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: arithmetic zero crossed safe return");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: accepted arithmetic raw-pointer return changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func check_tables(ctx: &Arena) {
    mut subs: std.Vector[int, ctx] := std.VectorNew(ctx);
    subs.Push(0); subs.Push(0); subs.Push(0); subs.Push(0);
    subs.Push(0); subs.Push(1); subs.Push(2); subs.Push(3);
    subs.Push(0); subs.Push(2); subs.Push(0); subs.Push(0);
    subs.Push(0); subs.Push(3); subs.Push(0); subs.Push(3);
    mut muls: std.Vector[int, ctx] := std.VectorNew(ctx);
    muls.Push(0); muls.Push(1); muls.Push(0); muls.Push(3);
    muls.Push(1); muls.Push(1); muls.Push(1); muls.Push(1);
    muls.Push(0); muls.Push(1); muls.Push(0); muls.Push(3);
    muls.Push(3); muls.Push(1); muls.Push(3); muls.Push(3);
    mut left := 0;
    while left < 4 {
        mut right := 0;
        while right < 4 {
            if typechecker.phase26_zero_sub(left, right) != subs[left * 4 + right] ||
               typechecker.phase26_zero_mul(left, right) != muls[left * 4 + right] {
                os.LogStr("Error: arithmetic zero transfer table drifted");
                os.Exit(1);
            }
            right = right + 1;
        }
        left = left + 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_tables(ctx);
    check_return("func safe_sub() *int { unsafe { return (0 - 0) as *int; } }", 1, ctx);
    check_return("func safe_mul() *int { unsafe { return (0 * 0) as *int; } }", 1, ctx);
    check_return("func safe_factor(n: int) *int { unsafe { return (0 * n) as *int; } }", 1, ctx);
    check_return("func safe_nonzero() *int { unsafe { return (1 - 0) as *int; } }", 0, ctx);
    check_return("func safe_unknown(n: int) *int { unsafe { return (n - 0) as *int; } }", 0, ctx);
    check_return("unsafe func unsafe_zero() *int { return (0 * 0) as *int; }", 0, ctx);
    check_call("accept_raw((0 - 0) as *int);", 0, 1, ctx);
    check_call("accept_raw((0 * 0) as *int);", 0, 1, ctx);
    check_call("unsafe { mut n := 0 - 0; accept_raw(n as *int); }", 0, 1, ctx);
    check_call("unsafe { mut n := 1; if 1 { n = 0 * 0; } accept_raw(n as *int); }", 0, 1, ctx);
    check_call("accept_raw((1 - 0) as *int);", 0, 0, ctx);
    check_call("accept_raw((1 * 1) as *int);", 0, 0, ctx);
    check_call("accept_raw((0 * 0) as *int);", 1, 0, ctx);
    check_call("accept_raw(0);", 0, 2, ctx);
    os.LogStr("SUCCESS: arithmetic zero evidence tables, safe boundaries, and controls verified");
}
