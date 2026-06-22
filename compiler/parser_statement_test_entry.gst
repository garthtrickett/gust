import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "while 1 { mut x: int := 42; if x { x = 20; } else { x = 30; } guard mut y := 10 else { return; } }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut stmt := parser.parse_statement(&p, ctx);
}
