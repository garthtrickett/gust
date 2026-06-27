import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut l_layout: lexer.Lexer[ctx];
    lexer.init_lexer(&l_layout, "type CLike struct { x: int }");

    mut p_layout: parser.Parser[ctx];
    parser.init_parser(&p_layout, &l_layout, ctx);

    mut stmt_layout := parser.parse_statement(&p_layout, ctx);
    unsafe {
        if ctx[stmt_layout].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected struct declaration for layout metadata fixture");
            os.Exit(1);
        }
        if ctx[stmt_layout].StructDecl.is_repr_c != 0 {
            os.LogStr("Error: ordinary structs must default to non-repr-C layout metadata");
            os.Exit(1);
        }
        if ctx[stmt_layout].StructDecl.is_packed != 0 {
            os.LogStr("Error: ordinary structs must default to unpacked layout metadata");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt_layout].StructDecl.layout_abi, "") == 0 {
            os.LogStr("Error: ordinary structs must default to empty layout ABI metadata");
            os.Exit(1);
        }
    }

    os.LogStr("SUCCESS: struct layout metadata defaults verified!");
}