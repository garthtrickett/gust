import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_close_after_move := typechecker.env_new(ctx);
    env_close_after_move.current_prefix = "main__";
    mut scope_close_after_move := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_close_after_move, "main__CloseAfterMovePayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_close_after_move, "main__CloseAfterMovePayload", "main__close_close_after_move_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_close_after_move, "main__close_after_move_resource", "main__CloseAfterMovePayload", ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_close_after_move, "main__close_after_move_resource", ctx) != 1 {
        os.LogStr("Error: close-after-move fixture resource must start owned");
        os.Exit(1);
    }
    if typechecker.env_try_move_open_linear_resource(&env_close_after_move, "main__close_after_move_resource", ctx) != 1 {
        os.LogStr("Error: close-after-move fixture failed to move tracked resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_close_after_move, "main__close_after_move_resource", ctx) != 1 {
        os.LogStr("Error: close-after-move fixture resource must be moved before destructor call");
        os.Exit(1);
    }

    mut span_close_after_move: token.Span;
    mut close_arg_expr_close_after_move: ast.Expression[ctx];
    unsafe {
        close_arg_expr_close_after_move.tag = 0; // Identifier
        close_arg_expr_close_after_move.Identifier.name = "close_after_move_resource";
        close_arg_expr_close_after_move.Identifier.span = span_close_after_move;
    }
    mut close_args_close_after_move: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    close_args_close_after_move.Push(close_arg_expr_close_after_move);
    mut close_args_idx_close_after_move: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(close_args_idx_close_after_move, close_args_close_after_move);

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_close_after_move, "main__close_close_after_move_payload", close_args_idx_close_after_move, scope_close_after_move, ctx) != 0 {
        os.LogStr("Error: destructor call must not close a moved tracked resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_close_after_move, "main__close_after_move_resource", ctx) != 1 {
        os.LogStr("Error: rejected close-after-move must leave resource in moved state");
        os.Exit(1);
    }
    if len(env_close_after_move.errors) == 0 {
        os.LogStr("Error: destructor call after move must report LinearResourceCloseAfterMove");
        os.Exit(1);
    }
    if std.str_find(env_close_after_move.errors[0].message, "LinearResourceCloseAfterMove") == 0 - 1 {
        os.LogStr("Error: destructor call after move emitted wrong diagnostic");
        os.LogStr(env_close_after_move.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource close-after-move rejection verified!");
}