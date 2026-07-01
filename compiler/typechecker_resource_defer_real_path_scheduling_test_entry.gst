import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_defer_schedule := typechecker.env_new(ctx);
    env_defer_schedule.current_prefix = "main__";
    mut scope_defer_schedule := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_defer_schedule, "main__DeferSchedulePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_defer_schedule, "main__DeferSchedulePayload", "close_defer_schedule_payload", ctx);

    mut span_defer_schedule: token.Span;
    mut payload_defer_schedule := typechecker.make_type_struct("main__DeferSchedulePayload", "", ctx);
    mut resource_defer_schedule := typechecker.make_type_resource(payload_defer_schedule, ctx);
    mut resource_type_idx_defer_schedule: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_defer_schedule, resource_defer_schedule);

    mut decl_defer_schedule: ast.Statement[ctx];
    unsafe {
        decl_defer_schedule.tag = 4; // VarDecl
        decl_defer_schedule.VarDecl.name = "scheduled_resource";
        decl_defer_schedule.VarDecl.is_mut = 1;
        decl_defer_schedule.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_defer_schedule.VarDecl.var_type = resource_type_idx_defer_schedule;
        decl_defer_schedule.VarDecl.span = span_defer_schedule;
    }
    mut decl_idx_defer_schedule: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_idx_defer_schedule, decl_defer_schedule);
    typechecker.check_statement(decl_idx_defer_schedule, &env_defer_schedule, scope_defer_schedule, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_defer_schedule, "scheduled_resource", ctx) != 1 {
        os.LogStr("Error: setup Resource should start owned before real defer scheduling");
        os.Exit(1);
    }

    mut lex_defer_schedule: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_defer_schedule, "defer close_defer_schedule_payload(scheduled_resource);");
    mut parser_defer_schedule: parser.Parser[ctx];
    parser.init_parser(&parser_defer_schedule, &lex_defer_schedule, ctx);
    mut stmt_defer_schedule := parser.parse_statement(&parser_defer_schedule, ctx);

    typechecker.check_statement(stmt_defer_schedule, &env_defer_schedule, scope_defer_schedule, ctx);

    if len(env_defer_schedule.errors) != 0 {
        os.LogStr("Error: canonical Resource defer scheduling should not emit a diagnostic");
        os.LogStr(env_defer_schedule.errors[0].message);
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_defer_schedule, "scheduled_resource", ctx) != 1 {
        os.LogStr("Error: real canonical Resource defer should mark the Resource destructor_scheduled");
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_closed(&env_defer_schedule, "scheduled_resource", ctx) != 0 {
        os.LogStr("Error: real Resource defer scheduling must not mark the Resource closed");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: real Resource defer scheduling path verified!");
}