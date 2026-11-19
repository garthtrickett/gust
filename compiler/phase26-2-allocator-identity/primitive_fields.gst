import "../ast.gst" as ast;
import "../lexer.gst" as lexer;
import "../parser.gst" as parser;
import "../typechecker.gst" as checker;
func main() int {
    mut ctx := os.Arena.New();
    unsafe {
        mut args := os.Args(&ctx);
        if len(args) != 2 { return 2; }
        mut lex: lexer.Lexer[ctx];
        lexer.init_lexer(&lex, args[1]);
        mut parse: parser.Parser[ctx];
        parser.init_parser(&parse, &lex, &ctx);
        mut program := parser.parse_program(&parse, &ctx);
        if len(parse.errors) != 0 { os.LogStr("PARSER_FAILED"); return 3; }
        mut env := checker.env_new(&ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
        mut i := 0;
        while i < len(statements) { checker.env_pre_register_template_statement(&env, statements[i], &ctx); i = i + 1; }
        i = 0;
        while i < len(statements) { checker.env_pre_register_statement(&env, statements[i], &ctx); i = i + 1; }
        i = 0;
        while i < len(statements) {
            mut statement: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(&ctx);
            ctx.Set(statement, statements[i]);
            checker.check_statement(statement, &env, scope, &ctx);
            i = i + 1;
        }
        if len(env.errors) == 0 { os.LogStr("ACCEPTED"); }
        else {
            i = 0;
            while i < len(env.errors) { os.LogStr(env.errors[i].message); i = i + 1; }
        }
    }
    return 0;
}
