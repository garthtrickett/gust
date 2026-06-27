import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if len(args) < 2 {
        os.LogStr("Usage: type_dump <file>");
        os.Exit(1);
    }
    mut file_path := args[1];
    mut source := os.ReadFile(ctx, file_path);
    if len(source) == 0 {
        os.LogStr("Error: empty file or failed to read");
        os.Exit(1);
    }

    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, source);

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    if len(p.errors) > 0 {
        os.LogStr("ParserError");
        os.Exit(1);
    }

    mut env := typechecker.env_new(ctx);
    env.current_file = file_path;
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut statements_vec: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];

    mut i := 0;
    while i < len(statements_vec) {
        typechecker.env_pre_register_statement(&env, statements_vec[i], ctx);
        i = i + 1;
    }

    mut j := 0;
    while j < len(statements_vec) {
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx.Set(stmt_idx, statements_vec[j]);
        typechecker.check_statement(stmt_idx, &env, scope, ctx);
        j = j + 1;
    }

    if len(env.errors) > 0 {
        mut k := 0;
        while k < len(env.errors) {
            mut err := env.errors[k];
            mut msg := std.Format("TypeError at line %d:%d: %s", err.span.start.line, err.span.start.column, err.message);
            os.LogStr(msg);
            k = k + 1;
        }
        os.Exit(1);
    }

    mut serialized := typechecker.typechecker_serialize_type_environment(&env, ctx);
    os.LogStr(serialized);
}
