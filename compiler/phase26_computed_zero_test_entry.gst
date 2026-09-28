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
            os.LogStr("Error: computed zero did not reject at safe argument");
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
        os.LogStr("Error: accepted raw-pointer argument changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func check_return(src: str, rejected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut stmt := parse_statement(src, ctx);
    typechecker.check_statement(stmt, &env, scope, ctx);
    if rejected == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: computed zero did not reject at safe return");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: accepted raw-pointer return changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func check_tables(ctx: &Arena) {
    mut joins: std.Vector[int, ctx] := std.VectorNew(ctx);
    joins.Push(0); joins.Push(3); joins.Push(0); joins.Push(3);
    joins.Push(3); joins.Push(1); joins.Push(3); joins.Push(3);
    joins.Push(0); joins.Push(3); joins.Push(2); joins.Push(3);
    joins.Push(3); joins.Push(3); joins.Push(3); joins.Push(3);
    mut adds: std.Vector[int, ctx] := std.VectorNew(ctx);
    adds.Push(0); adds.Push(0); adds.Push(0); adds.Push(0);
    adds.Push(0); adds.Push(1); adds.Push(2); adds.Push(3);
    adds.Push(0); adds.Push(2); adds.Push(0); adds.Push(0);
    adds.Push(0); adds.Push(3); adds.Push(0); adds.Push(3);
    mut a := 0;
    while a < 4 {
        mut b := 0;
        while b < 4 {
            if typechecker.phase26_zero_join(a, b) != joins[a * 4 + b] ||
               typechecker.phase26_zero_add(a, b) != adds[a * 4 + b] {
                os.LogStr("Error: zero-state table drifted");
                os.Exit(1);
            }
            mut c := 0;
            while c < 4 {
                if typechecker.phase26_zero_join(typechecker.phase26_zero_join(a, b), c) !=
                   typechecker.phase26_zero_join(a, typechecker.phase26_zero_join(b, c)) {
                    os.LogStr("Error: zero-state join is not associative");
                    os.Exit(1);
                }
                c = c + 1;
            }
            b = b + 1;
        }
        a = a + 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_tables(ctx);
    check_return("func safe_zero_sum() *int { unsafe { return (0 + 0) as *int; } }", 1, ctx);
    check_return("func safe_nonzero() *int { unsafe { return (1 + 0) as *int; } }", 0, ctx);
    check_return("func safe_unknown(n: int) *int { unsafe { return n as *int; } }", 0, ctx);
    check_return("unsafe func unsafe_zero() *int { return (0 + 0) as *int; }", 0, ctx);
    check_call("accept_raw((0 + 0) as *int);", 0, 1, ctx);
    check_call("unsafe { mut n := 0; accept_raw(n as *int); }", 0, 1, ctx);
    check_call("unsafe { mut n := 0; mut alias := n; accept_raw(alias as *int); }", 0, 1, ctx);
    check_call("unsafe { mut n := 1; if 1 { n = 0; } accept_raw(n as *int); }", 0, 1, ctx);
    check_call("unsafe { mut n := 1; while n { n = 0; } accept_raw(n as *int); }", 0, 1, ctx);
    check_call("unsafe { mut n := 1; if 1 { mut n := 0; } accept_raw(n as *int); }", 0, 0, ctx);
    check_call("accept_raw((1 + 0) as *int);", 0, 0, ctx);
    check_call("accept_raw((0 + 0) as *int);", 1, 0, ctx);
    check_call("accept_raw(0);", 0, 2, ctx);
    os.LogStr("SUCCESS: computed-zero raw-pointer safe-boundary value table and flow verified");
}
