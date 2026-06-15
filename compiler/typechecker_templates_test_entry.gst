import "ast.gst" as ast;
import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    // Verify standard templates are loaded
    if env.struct_templates.Get("Vector").Ok {
        os.LogStr("Vector template found");
    } else {
        os.LogStr("Vector template missing");
    }

    if env.struct_templates.Get("std_HashMap").Ok {
        os.LogStr("std_HashMap template found");
    } else {
        os.LogStr("std_HashMap template missing");
    }

    // Parse a custom generic structure: type Custom[T] struct { x: T }
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Custom[T] struct { x: T }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    if len(p.errors) > 0 {
        os.LogStr("ParserError");
        os.Exit(1);
    }

    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        if len(*statements_vec) > 0 {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
        }
    }

    // Verify "Custom" was registered as a template and NOT a concrete struct
    if env.struct_templates.Get("Custom").Ok {
        os.LogStr("Custom registered as template");
    } else {
        os.LogStr("Custom template missing");
    }

    if env.struct_registry.Get("Custom").Ok {
        os.LogStr("Error: Custom registered in concrete registry");
    } else {
        os.LogStr("Custom absent from concrete registry");
    }
}