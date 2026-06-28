import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut l_plain_linear_meta: lexer.Lexer[ctx];
    lexer.init_lexer(&l_plain_linear_meta, "type PlainResourceMetadata struct { fd: int }");
    mut p_plain_linear_meta: parser.Parser[ctx];
    parser.init_parser(&p_plain_linear_meta, &l_plain_linear_meta, ctx);
    mut stmt_plain_linear_meta := parser.parse_statement(&p_plain_linear_meta, ctx);

    unsafe {
        if ctx[stmt_plain_linear_meta].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected plain struct declaration for linear metadata fixture");
            os.Exit(1);
        }
        if ctx[stmt_plain_linear_meta].StructDecl.is_linear_resource != 0 {
            os.LogStr("Error: ordinary structs must default to non-linear resource metadata");
            os.Exit(1);
        }
    }

    mut l_marked_linear_meta: lexer.Lexer[ctx];
    lexer.init_lexer(&l_marked_linear_meta, "#[linear] type LinearResourceMetadata struct { fd: int }");
    mut p_marked_linear_meta: parser.Parser[ctx];
    parser.init_parser(&p_marked_linear_meta, &l_marked_linear_meta, ctx);
    mut stmt_marked_linear_meta := parser.parse_statement(&p_marked_linear_meta, ctx);

    unsafe {
        if ctx[stmt_marked_linear_meta].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected #[linear] struct declaration for linear metadata fixture");
            os.Exit(1);
        }
        if ctx[stmt_marked_linear_meta].StructDecl.is_linear_resource != 1 {
            os.LogStr("Error: #[linear] structs must enable linear resource metadata");
            os.Exit(1);
        }
        if ctx[stmt_marked_linear_meta].StructDecl.is_repr_c != 0 {
            os.LogStr("Error: #[linear] alone must not imply repr-C layout metadata");
            os.Exit(1);
        }
        if ctx[stmt_marked_linear_meta].StructDecl.is_packed != 0 {
            os.LogStr("Error: #[linear] alone must not imply packed layout metadata");
            os.Exit(1);
        }
    }

    mut l_combined_linear_meta: lexer.Lexer[ctx];
    lexer.init_lexer(&l_combined_linear_meta, "#[repr(C)] #[linear] type CLinearResourceMetadata struct { fd: int }");
    mut p_combined_linear_meta: parser.Parser[ctx];
    parser.init_parser(&p_combined_linear_meta, &l_combined_linear_meta, ctx);
    mut stmt_combined_linear_meta := parser.parse_statement(&p_combined_linear_meta, ctx);

    unsafe {
        if ctx[stmt_combined_linear_meta].tag != 1 { // StructDecl = 1
            os.LogStr("Error: expected combined repr(C)/linear struct declaration");
            os.Exit(1);
        }
        if ctx[stmt_combined_linear_meta].StructDecl.is_repr_c != 1 {
            os.LogStr("Error: combined repr(C)/linear metadata must keep repr-C enabled");
            os.Exit(1);
        }
        if std.str_eq(ctx[stmt_combined_linear_meta].StructDecl.layout_abi, "C") == 0 {
            os.LogStr("Error: combined repr(C)/linear metadata must keep C ABI metadata");
            os.Exit(1);
        }
        if ctx[stmt_combined_linear_meta].StructDecl.is_linear_resource != 1 {
            os.LogStr("Error: combined repr(C)/linear metadata must keep linear resource enabled");
            os.Exit(1);
        }
    }

    mut env_linear_meta := typechecker.env_new(ctx);
    typechecker.env_register_struct_linear_metadata(&env_linear_meta, "main__PlainResourceMetadata", 0, ctx);
    if typechecker.env_struct_is_linear_resource(&env_linear_meta, "main__PlainResourceMetadata", ctx) != 0 {
        os.LogStr("Error: plain struct linear metadata lookup must default to disabled");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_metadata(&env_linear_meta, "main__LinearResourceMetadata", 1, ctx);
    if typechecker.env_struct_is_linear_resource(&env_linear_meta, "main__LinearResourceMetadata", ctx) != 1 {
        os.LogStr("Error: linear resource metadata lookup failed");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_metadata(&env_linear_meta, "main__LinearResourceMetadata", ctx) != 1 {
        os.LogStr("Error: linear resource metadata predicate failed");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_metadata(&env_linear_meta, "main__MissingLinearResourceMetadata", ctx) != 0 {
        os.LogStr("Error: missing linear resource metadata must default to disabled");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear resource metadata opt-in verified!");
}