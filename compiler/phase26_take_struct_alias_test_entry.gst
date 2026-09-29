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

func check_alias_flow(write: str, transfer: str, unsafe_callee: int, expect_rejection: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut raw_type := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut holder_type := typechecker.make_type_struct("Holder", "", ctx);
    mut layout: typechecker.StructLayout[ctx];
    layout.brand = empty[Index[str, ctx]];
    layout.fields = std.HashMapNew(ctx);
    layout.fields.Insert("ptr", raw_type);
    typechecker.env_register_struct(&env, "Holder", layout, ctx);
    typechecker.scope_insert(scope, "holder", holder_type, ctx);
    typechecker.scope_insert(scope, "input", raw_type, ctx);

    mut void_type: ast.Type[ctx];
    unsafe { void_type.tag = 3; }
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.param_names.Push("ptr");
    sig.params.Push(raw_type);
    sig.return_type = void_type;
    sig.return_origins = typechecker.set_init(ctx);
    sig.is_unsafe = unsafe_callee;
    typechecker.env_register_function(&env, "accept_raw", sig, ctx);
    env.in_unsafe_block = 1;

    typechecker.check_statement(parse_statement(write, ctx), &env, scope, ctx);
    if std.str_eq(transfer, "assign") == 1 {
        typechecker.scope_insert(scope, "alias", holder_type, ctx);
        typechecker.check_statement(parse_statement("alias = take holder;", ctx), &env, scope, ctx);
    } else if std.str_eq(transfer, "plain") == 1 {
        typechecker.check_statement(parse_statement("mut alias := holder;", ctx), &env, scope, ctx);
    } else {
        typechecker.check_statement(parse_statement("mut alias := take holder;", ctx), &env, scope, ctx);
    }
    if len(env.errors) != 0 {
        os.LogStr("Error: local Struct setup failed before safe call");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    typechecker.check_statement(parse_statement("accept_raw(alias.ptr);", ctx), &env, scope, ctx);
    if expect_rejection == 1 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[RawNullSafeBoundary]") == 0 - 1 {
            os.LogStr("Error: known zero in taken Struct crossed safe call");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: nonzero, unknown, or unsafe Struct take control changed");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_alias_flow("holder.ptr = (0 + 0) as *int;", "decl", 0, 1, ctx);
    check_alias_flow("holder.ptr = (0 + 0) as *int;", "assign", 0, 1, ctx);
    check_alias_flow("holder.ptr = (0 + 0) as *int;", "plain", 0, 1, ctx);
    check_alias_flow("holder.ptr = 1 as *int;", "decl", 0, 0, ctx);
    check_alias_flow("holder.ptr = 1 as *int;", "assign", 0, 0, ctx);
    check_alias_flow("holder.ptr = input;", "decl", 0, 0, ctx);
    check_alias_flow("holder.ptr = input;", "assign", 0, 0, ctx);
    check_alias_flow("holder.ptr = (0 + 0) as *int;", "decl", 1, 0, ctx);
    check_alias_flow("holder.ptr = (0 + 0) as *int;", "assign", 1, 0, ctx);
    os.LogStr("SUCCESS: taken local Struct field evidence and controls verified");
    return 0;
}
