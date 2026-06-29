import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_close_call := typechecker.env_new(ctx);
    env_close_call.current_prefix = "main__";
    mut scope_close_call := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_close_call, "main__CloseCallPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_close_call, "main__CloseCallPayload", "main__close_close_call_payload", ctx);

    mut span_close_call: token.Span;

    mut payload_close_call := typechecker.make_type_struct("main__CloseCallPayload", "", ctx);
    mut resource_close_call := typechecker.make_type_resource(payload_close_call, ctx);
    mut resource_type_idx_close_call: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_close_call, resource_close_call);

    mut resource_decl_close_call: ast.Statement[ctx];
    unsafe {
        resource_decl_close_call.tag = 4; // VarDecl
        resource_decl_close_call.VarDecl.name = "tracked_close_call_resource";
        resource_decl_close_call.VarDecl.is_mut = 1;
        resource_decl_close_call.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        resource_decl_close_call.VarDecl.var_type = resource_type_idx_close_call;
        resource_decl_close_call.VarDecl.span = span_close_call;
    }
    mut resource_decl_idx_close_call: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_decl_idx_close_call, resource_decl_close_call);
    typechecker.check_statement(resource_decl_idx_close_call, &env_close_call, scope_close_call, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_close_call, "tracked_close_call_resource", ctx) != 1 {
        os.LogStr("Error: Resource must start owned before destructor call tracking");
        os.Exit(1);
    }

    mut close_arg_expr_close_call: ast.Expression[ctx];
    unsafe {
        close_arg_expr_close_call.tag = 0; // Identifier
        close_arg_expr_close_call.Identifier.name = "tracked_close_call_resource";
        close_arg_expr_close_call.Identifier.span = span_close_call;
    }
    mut close_args_close_call: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    close_args_close_call.Push(close_arg_expr_close_call);
    mut close_args_idx_close_call: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(close_args_idx_close_call, close_args_close_call);

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_close_call, "main__close_close_call_payload", close_args_idx_close_call, scope_close_call, ctx) != 1 {
        os.LogStr("Error: Resource destructor call did not mark resource closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_close_call, "tracked_close_call_resource", ctx) != 1 {
        os.LogStr("Error: Resource destructor call did not leave resource in closed state");
        os.Exit(1);
    }
    mut wrong_resource_decl_close_call: ast.Statement[ctx];
    unsafe {
        wrong_resource_decl_close_call.tag = 4; // VarDecl
        wrong_resource_decl_close_call.VarDecl.name = "wrong_destructor_resource";
        wrong_resource_decl_close_call.VarDecl.is_mut = 1;
        wrong_resource_decl_close_call.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        wrong_resource_decl_close_call.VarDecl.var_type = resource_type_idx_close_call;
        wrong_resource_decl_close_call.VarDecl.span = span_close_call;
    }
    mut wrong_resource_decl_idx_close_call: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(wrong_resource_decl_idx_close_call, wrong_resource_decl_close_call);
    typechecker.check_statement(wrong_resource_decl_idx_close_call, &env_close_call, scope_close_call, ctx);

    mut wrong_arg_expr_close_call: ast.Expression[ctx];
    unsafe {
        wrong_arg_expr_close_call.tag = 0; // Identifier
        wrong_arg_expr_close_call.Identifier.name = "wrong_destructor_resource";
        wrong_arg_expr_close_call.Identifier.span = span_close_call;
    }
    mut wrong_args_close_call: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    wrong_args_close_call.Push(wrong_arg_expr_close_call);
    mut wrong_args_idx_close_call: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(wrong_args_idx_close_call, wrong_args_close_call);

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_close_call, "main__not_the_destructor", wrong_args_idx_close_call, scope_close_call, ctx) != 0 {
        os.LogStr("Error: Non-destructor call must not close tracked resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_close_call, "wrong_destructor_resource", ctx) != 1 {
        os.LogStr("Error: Non-destructor call changed resource state");
        os.Exit(1);
    }

    if len(env_close_call.errors) != 0 {
        os.LogStr("Error: Resource destructor call tracking produced unexpected typechecker error");
        os.LogStr(env_close_call.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource destructor call tracking verified!");
}
