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

func parse_expression(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func check_return(src: str, rejected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut stmt := parse_statement(src, ctx);
    typechecker.check_statement(stmt, &env, scope, ctx);
    if rejected == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: safe raw-null return missed exact semantic diagnostic");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: permitted raw-pointer return changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
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
            os.LogStr("Error: safe raw-null argument missed exact semantic diagnostic");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if expected == 2 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "Argument type mismatch") == 0 - 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") != 0 - 1 {
            os.LogStr("Error: type mismatch ordering changed");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: permitted raw-pointer argument changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func check_bound_call(ctx: &Arena) {
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
    sig.is_unsafe = 0;
    sig.param_names.Push("ptr");
    sig.params.Push(raw_type);
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    env.in_unsafe_block = 1;
    mut bind := parse_statement("mut p: *int := 0 as *int;", ctx);
    typechecker.check_statement(bind, &env, scope, ctx);
    if len(env.errors) != 0 {
        os.LogStr("Error: local unsafe raw-pointer binding changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    mut call := parse_statement("accept_raw(p);", ctx);
    typechecker.check_statement(call, &env, scope, ctx);
    if len(env.errors) != 1 ||
       std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
        os.LogStr("Error: bound zero-derived raw pointer crossed safe call");
        if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
        os.Exit(1);
    }
}

func check_unknown_call(ctx: &Arena) {
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
    sig.is_unsafe = 0;
    sig.param_names.Push("ptr");
    sig.params.Push(raw_type);
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    typechecker.scope_insert(scope, "unknown_raw", raw_type, ctx);
    env.variable_types.Insert("unknown_raw", raw_type);
    typechecker.env_record_variable_provenance(
        &env, "unknown_raw", typechecker.expression_provenance_unknown(raw_type, ctx), ctx
    );
    mut call := parse_statement("accept_raw(unknown_raw);", ctx);
    typechecker.check_statement(call, &env, scope, ctx);
    if len(env.errors) != 0 {
        os.LogStr("Error: unknown-origin raw pointer call changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_return("func safe_zero() *int { unsafe { mut p := 0 as *int; return p; } }", 1, ctx);
    check_return("func safe_nonzero() *int { unsafe { return 1 as *int; } }", 0, ctx);
    check_return("func safe_unknown(raw: *int) *int { return raw; }", 0, ctx);
    check_return("unsafe func unsafe_zero() *int { return 0 as *int; }", 0, ctx);
    check_call("accept_raw(0 as *int);", 0, 1, ctx);
    check_bound_call(ctx);
    check_call("accept_raw(1 as *int);", 0, 0, ctx);
    check_call("accept_raw(0 as *int);", 1, 0, ctx);
    check_call("accept_raw(0);", 0, 2, ctx);
    check_unknown_call(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    env.in_unsafe_block = 1;
    mut zero_expr := parse_expression("0 as *int", ctx);
    mut one_expr := parse_expression("1 as *int", ctx);
    mut zero_prov := typechecker.check_expression_with_provenance(zero_expr, &env, scope, ctx);
    mut one_prov := typechecker.check_expression_with_provenance(one_expr, &env, scope, ctx);
    if typechecker.set_contains(zero_prov.legacy_origins, "phase26.raw_null_zero_cast", ctx) != 1 ||
       typechecker.set_contains(one_prov.legacy_origins, "phase26.raw_null_zero_cast", ctx) != 0 {
        os.LogStr("Error: zero and nonzero raw casts were classified incorrectly");
        os.Exit(1);
    }
    mut null_expr := parse_expression("null", ctx);
    mut null_prov := typechecker.check_expression_with_provenance(null_expr, &env, scope, ctx);
    if typechecker.set_contains(null_prov.legacy_origins, "null", ctx) != 1 ||
       typechecker.set_contains(null_prov.legacy_origins, "phase26.raw_null_zero_cast", ctx) != 0 {
        os.LogStr("Error: bare null Index sentinel changed");
        os.Exit(1);
    }
    os.LogStr("SUCCESS: known-zero raw pointer safe-boundary policy verified");
}
