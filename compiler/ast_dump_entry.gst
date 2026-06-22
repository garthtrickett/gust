import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if len(args) < 2 {
        os.LogStr("Usage: ast_dump <file>");
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
    mut serialized := ast.serialize_program(&prog, 0, ctx);
    os.LogStr(serialized);
}
