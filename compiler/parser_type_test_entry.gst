import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type MyStruct[T] struct { x: int, y: bool }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut stmt := parser.parse_statement(&p, ctx);
    mut s_name := "";
    unsafe {
        s_name = ctx[stmt].StructDecl.name;
    }
    os.LogInt(ctx[stmt].tag);
    os.LogStr(s_name);

    mut l2: lexer.Lexer[ctx];
    lexer.init_lexer(&l2, "type MyEnum enum { Circle { r: int }, Point }");

    mut p2: parser.Parser[ctx];
    parser.init_parser(&p2, &l2, ctx);

    mut stmt2 := parser.parse_statement(&p2, ctx);
    mut s2_name := "";
    unsafe {
        s2_name = ctx[stmt2].EnumDecl.name;
    }
    os.LogInt(ctx[stmt2].tag);
    os.LogStr(s2_name);
}
