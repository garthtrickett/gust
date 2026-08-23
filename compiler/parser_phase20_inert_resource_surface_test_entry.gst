import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func expect_attribute_error(source: str, expected: str, ctx: &Arena) {
    mut fixture_lexer: lexer.Lexer[ctx];
    lexer.init_lexer(&fixture_lexer, source);
    mut fixture_parser: parser.Parser[ctx];
    parser.init_parser(&fixture_parser, &fixture_lexer, ctx);
    mut fixture_program := parser.parse_program(&fixture_parser, ctx);
    if len(fixture_parser.errors) == 0 {
        os.LogStr("Error: malformed declaration attribute unexpectedly parsed");
        os.Exit(1);
    }
    if std.str_eq(fixture_parser.errors[0].message, expected) == 0 {
        os.LogStr("Error: declaration attribute diagnostic drifted");
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut surface_lexer: lexer.Lexer[ctx];
    lexer.init_lexer(
        &surface_lexer,
        "#[linear] #[destructor(close_guard)] #[opaque] type Guard struct { token: int } #[private] func close_guard(value: Guard) { }"
    );
    mut surface_parser: parser.Parser[ctx];
    parser.init_parser(&surface_parser, &surface_lexer, ctx);
    mut surface_program := parser.parse_program(&surface_parser, ctx);
    if len(surface_parser.errors) != 0 {
        os.LogStr("Error: valid inert declaration attributes did not parse");
        os.Exit(1);
    }

    mut surface_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[surface_program.statements];
    if len(surface_statements) != 2 {
        os.LogStr("Error: expected resource type and private cleanup declaration");
        os.Exit(1);
    }
    if surface_statements[0].tag != 1 || surface_statements[1].tag != 3 {
        os.LogStr("Error: inert attributes changed declaration AST variants");
        os.Exit(1);
    }
    unsafe {
        if std.str_eq(surface_statements[0].StructDecl.declared_destructor_name, "close_guard") == 0 ||
           surface_statements[0].StructDecl.is_opaque != 1 ||
           surface_statements[0].StructDecl.is_linear_resource != 1 ||
           surface_statements[1].FunctionDecl.is_private != 1
        {
            os.LogStr("Error: inert declaration AST metadata was not preserved");
            os.Exit(1);
        }
    }

    mut serialized_surface := ast.serialize_program(&surface_program, 0, ctx);
    if std.str_find(serialized_surface, "#[destructor(close_guard)] #[opaque]") == 0 - 1 ||
       std.str_find(serialized_surface, "#[private]") == 0 - 1
    {
        os.LogStr("Error: inert declaration attributes did not survive AST serialization");
        os.Exit(1);
    }

    mut surface_env := typechecker.env_new(ctx);
    typechecker.env_pre_register_statement(&surface_env, surface_statements[0], ctx);
    typechecker.env_pre_register_statement(&surface_env, surface_statements[1], ctx);
    if std.str_eq(typechecker.env_struct_declared_destructor_name(&surface_env, "Guard", ctx), "close_guard") == 0 ||
       typechecker.env_struct_is_declared_opaque(&surface_env, "Guard", ctx) != 1
    {
        os.LogStr("Error: inert resource type metadata was not registered");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_destructor(&surface_env, "Guard", ctx) != 0 {
        os.LogStr("Error: declared destructor enabled cleanup enforcement early");
        os.Exit(1);
    }
    mut private_lookup := surface_env.function_registry.Get("close_guard");
    if private_lookup.Ok == false {
        os.LogStr("Error: inert private function metadata was not registered");
        os.Exit(1);
    }
    if private_lookup.Ok {
        if private_lookup.Val.is_private != 1 {
            os.LogStr("Error: inert private function metadata was not preserved");
            os.Exit(1);
        }
    }

    expect_attribute_error(
        "#[destructor] type Guard struct { token: int }",
        "Expected '(' after destructor attribute",
        ctx
    );
    expect_attribute_error(
        "#[destructor()] type Guard struct { token: int }",
        "Expected function name in destructor attribute",
        ctx
    );
    expect_attribute_error(
        "#[opaque type Guard struct { token: int }",
        "Expected closing ']' after layout attribute",
        ctx
    );
    expect_attribute_error(
        "#[destructor(first)] #[destructor(second)] type Guard struct { token: int }",
        "Duplicate destructor declaration attribute",
        ctx
    );
    expect_attribute_error(
        "#[opaque] #[opaque] type Guard struct { token: int }",
        "Duplicate opaque declaration attribute",
        ctx
    );
    expect_attribute_error(
        "#[private] #[private] func close_guard() { }",
        "Duplicate private declaration attribute",
        ctx
    );
    expect_attribute_error(
        "#[opaque] #[private] func close_guard() { }",
        "Private function attribute conflicts with type declaration attributes",
        ctx
    );

    os.LogStr("SUCCESS: inert resource declaration and visibility surface verified!");
}
