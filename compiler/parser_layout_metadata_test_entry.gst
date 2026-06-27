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

    mut l_layout_repr: lexer.Lexer[ctx];
    lexer.init_lexer(&l_layout_repr, "#[repr(C)] type CLikeRepr struct { x: int }");

    mut p_layout_repr: parser.Parser[ctx];
    parser.init_parser(&p_layout_repr, &l_layout_repr, ctx);

    mut stmt_layout_repr := parser.parse_statement(&p_layout_repr, ctx);
    unsafe {
        if ctx[stmt_layout_repr].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected repr(C) struct declaration for layout metadata fixture");
            os.Exit(1);
        }
        if ctx[stmt_layout_repr].StructDecl.is_repr_c != 1 {
            os.LogStr("Error: repr(C) structs must enable repr-C layout metadata");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt_layout_repr].StructDecl.layout_abi, "C") == 0 {
            os.LogStr("Error: repr(C) structs must set layout ABI metadata to C");
            os.Exit(1);
        }
        if ctx[stmt_layout_repr].StructDecl.is_packed != 0 {
            os.LogStr("Error: repr(C) alone must not enable packed layout metadata");
            os.Exit(1);
        }
    }

    mut l_layout_packed: lexer.Lexer[ctx];
    lexer.init_lexer(&l_layout_packed, "#[packed] type PackedLike struct { y: int }");

    mut p_layout_packed: parser.Parser[ctx];
    parser.init_parser(&p_layout_packed, &l_layout_packed, ctx);

    mut stmt_layout_packed := parser.parse_statement(&p_layout_packed, ctx);
    unsafe {
        if ctx[stmt_layout_packed].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected packed struct declaration for layout metadata fixture");
            os.Exit(1);
        }
        if ctx[stmt_layout_packed].StructDecl.is_packed != 1 {
            os.LogStr("Error: packed structs must enable packed layout metadata");
            os.Exit(1);
        }
        if ctx[stmt_layout_packed].StructDecl.is_repr_c != 0 {
            os.LogStr("Error: packed alone must not enable repr-C layout metadata");
            os.Exit(1);
        }
    }

    mut l_layout_both: lexer.Lexer[ctx];
    lexer.init_lexer(&l_layout_both, "#[repr(C)] #[packed] type PackedCLike struct { z: int }");

    mut p_layout_both: parser.Parser[ctx];
    parser.init_parser(&p_layout_both, &l_layout_both, ctx);

    mut stmt_layout_both := parser.parse_statement(&p_layout_both, ctx);
    unsafe {
        if ctx[stmt_layout_both].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected combined layout attribute struct declaration");
            os.Exit(1);
        }
        if ctx[stmt_layout_both].StructDecl.is_repr_c != 1 {
            os.LogStr("Error: combined layout attributes must keep repr-C metadata");
            os.Exit(1);
        }
        if ctx[stmt_layout_both].StructDecl.is_packed != 1 {
            os.LogStr("Error: combined layout attributes must keep packed metadata");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt_layout_both].StructDecl.layout_abi, "C") == 0 {
            os.LogStr("Error: combined layout attributes must keep C ABI metadata");
            os.Exit(1);
        }
    }

    os.LogStr("SUCCESS: struct layout metadata defaults and attributes verified!");
}
