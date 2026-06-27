import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "extern func c_add(x: int) int { return x; }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut stmt := parser.parse_statement(&p, ctx);
    unsafe {
        if ctx[stmt].tag != 3 { // FunctionDecl = 3
            os.LogStr("Error: expected extern function declaration statement");
            os.Exit(1);
        }
        if ctx[stmt].FunctionDecl.is_extern != 1 {
            os.LogStr("Error: expected extern function metadata to be enabled");
            os.Exit(1);
        }
        if ctx[stmt].FunctionDecl.requires_unsafe_call != 1 {
            os.LogStr("Error: expected extern function calls to require unsafe metadata");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt].FunctionDecl.extern_symbol_name, "c_add") == 0 {
            os.LogStr("Error: expected extern symbol name to default to function name");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt].FunctionDecl.extern_abi, "C") == 0 {
            os.LogStr("Error: expected extern ABI to default to C");
            os.Exit(1);
        }
        if ctx[stmt].FunctionDecl.requires_layout_metadata != 0 {
            os.LogStr("Error: extern parser marker must not require layout metadata yet");
            os.Exit(1);
        }
        if ctx[stmt].FunctionDecl.requires_sandbox_arena != 0 {
            os.LogStr("Error: extern parser marker must not require sandbox arena metadata yet");
            os.Exit(1);
        }
    }

    os.LogStr("SUCCESS: extern function parser metadata verified!");
}