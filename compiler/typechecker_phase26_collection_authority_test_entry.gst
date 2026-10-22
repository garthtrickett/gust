import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;
import "mir_native_backend_full_program_source.gst" as fullprog;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut source := "func remove(ctx: &Arena, values: &std.Vector[int, ctx]) int { return values.Pop(); } func main() int { mut arena := os.Arena.New(); mut values: std.Vector[int, arena] := std.VectorNew(arena); values.Push(7); return remove(arena, &values); }";
    mut args := os.Args(ctx);
    if len(args) > 1 { source = args[1]; }
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, source);
    mut parse: parser.Parser[ctx];
    parser.init_parser(&parse, &lex, ctx);
    mut program := parser.parse_program(&parse, ctx);
    if len(parse.errors) != 0 { fail("R4 producer probe parser failed"); }
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    mut index := 0;
    while index < len(statements) {
        typechecker.env_pre_register_template_statement(&env, statements[index], ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(statements) {
        typechecker.env_pre_register_statement(&env, statements[index], ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(statements) {
        mut statement: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx.Set(statement, statements[index]);
        typechecker.check_statement(statement, &env, scope, ctx);
        index = index + 1;
    }
    if len(env.errors) != 0 { fail(env.errors[0].message); }
    mut programs: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    programs.Push(program);
    mut prefixes: std.Vector[str, ctx] := std.VectorNew(ctx);
    prefixes.Push("");
    mut paths: std.Vector[str, ctx] := std.VectorNew(ctx);
    paths.Push("collection-producer.gst");
    mut model := fullprog.mir_native_full_program_analyze_signatures(programs, prefixes, &env, ctx);
    if model.invalid == 1 || model.represented == 0 { fail("R4 full producer did not represent typed operations"); }
    mut serialized := fullprog.mir_native_full_program_serialize_model(model, paths, prefixes, ctx);
    if std.str_find(serialized, "|collection_pop.v1|") == 0 - 1 { fail("R4 Pop copy authority was not serialized"); }
    os.LogStr(serialized);
}
