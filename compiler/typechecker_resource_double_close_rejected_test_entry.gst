import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_double_close := typechecker.env_new(ctx);
    env_double_close.current_prefix = "main__";
    mut scope_double_close := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_double_close, "main__DoubleClosePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_double_close, "main__DoubleClosePayload", "main__close_double_close_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_double_close, "main__double_close_resource", "main__DoubleClosePayload", ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_double_close, "main__double_close_resource", ctx) != 1 {
        os.LogStr("Error: double-close fixture resource must start owned");
        os.Exit(1);
    }

    mut span_double_close: token.Span;
    mut close_arg_expr_double_close: ast.Expression[ctx];
    unsafe {
        close_arg_expr_double_close.tag = 0; // Identifier
        close_arg_expr_double_close.Identifier.name = "double_close_resource";
        close_arg_expr_double_close.Identifier.span = span_double_close;
    }
    mut close_args_double_close: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    close_args_double_close.Push(close_arg_expr_double_close);
    mut close_args_idx_double_close: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(close_args_idx_double_close, close_args_double_close);

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_double_close, "main__close_double_close_payload", close_args_idx_double_close, scope_double_close, ctx) != 1 {
        os.LogStr("Error: first destructor call should close tracked resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_double_close, "main__double_close_resource", ctx) != 1 {
        os.LogStr("Error: first destructor call did not mark tracked resource closed");
        os.Exit(1);
    }
    if len(env_double_close.errors) != 0 {
        os.LogStr("Error: first destructor call should not report double-close");
        os.LogStr(env_double_close.errors[0].message);
        os.Exit(1);
    }

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_double_close, "main__close_double_close_payload", close_args_idx_double_close, scope_double_close, ctx) != 0 {
        os.LogStr("Error: second destructor call should not close resource again");
        os.Exit(1);
    }
    if len(env_double_close.errors) == 0 {
        os.LogStr("Error: second destructor call must report double-close");
        os.Exit(1);
    }
    if std.str_find(env_double_close.errors[0].message, "LinearResourceDoubleClose") == 0 - 1 {
        os.LogStr("Error: second destructor call emitted wrong diagnostic");
        os.LogStr(env_double_close.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource double-close rejection verified!");
}
