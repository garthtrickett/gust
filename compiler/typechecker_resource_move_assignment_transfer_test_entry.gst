import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_transfer := typechecker.env_new(ctx);
    env_transfer.current_prefix = "main__";
    mut scope_transfer := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_transfer, "main__TransferPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_transfer, "main__TransferPayload", "close_transfer_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_transfer, "main__TransferPlainPayload", 0, ctx);

    mut span_transfer: token.Span;

    mut payload_transfer := typechecker.make_type_struct("main__TransferPayload", "", ctx);
    mut resource_transfer := typechecker.make_type_resource(payload_transfer, ctx);
    mut resource_type_idx_transfer: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_transfer, resource_transfer);

    mut source_decl_transfer: ast.Statement[ctx];
    unsafe {
        source_decl_transfer.tag = 4; // VarDecl
        source_decl_transfer.VarDecl.name = "source_transfer_resource";
        source_decl_transfer.VarDecl.is_mut = 1;
        source_decl_transfer.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_transfer.VarDecl.var_type = resource_type_idx_transfer;
        source_decl_transfer.VarDecl.span = span_transfer;
    }
    mut source_decl_idx_transfer: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_transfer, source_decl_transfer);
    typechecker.check_statement(source_decl_idx_transfer, &env_transfer, scope_transfer, ctx);

    mut target_decl_transfer: ast.Statement[ctx];
    unsafe {
        target_decl_transfer.tag = 4; // VarDecl
        target_decl_transfer.VarDecl.name = "target_transfer_resource";
        target_decl_transfer.VarDecl.is_mut = 1;
        target_decl_transfer.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_transfer.VarDecl.var_type = resource_type_idx_transfer;
        target_decl_transfer.VarDecl.span = span_transfer;
    }
    mut target_decl_idx_transfer: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_transfer, target_decl_transfer);
    typechecker.check_statement(target_decl_idx_transfer, &env_transfer, scope_transfer, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_transfer, "source_transfer_resource", ctx) != 1 {
        os.LogStr("Error: source Resource declaration did not auto-register before move transfer");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer, "target_transfer_resource", ctx) != 1 {
        os.LogStr("Error: target Resource declaration did not auto-register before move transfer");
        os.Exit(1);
    }
    typechecker.env_mark_open_linear_resource_closed(&env_transfer, "target_transfer_resource", ctx);

    mut transfer_left: ast.Expression[ctx];
    unsafe {
        transfer_left.tag = 0; // Identifier
        transfer_left.Identifier.name = "target_transfer_resource";
        transfer_left.Identifier.span = span_transfer;
    }
    mut transfer_left_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(transfer_left_idx, transfer_left);

    mut transfer_value: ast.Expression[ctx];
    unsafe {
        transfer_value.tag = 0; // Identifier
        transfer_value.Identifier.name = "source_transfer_resource";
        transfer_value.Identifier.span = span_transfer;
    }
    mut transfer_value_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(transfer_value_idx, transfer_value);

    mut transfer_stmt: ast.Statement[ctx];
    unsafe {
        transfer_stmt.tag = 5; // Assignment
        transfer_stmt.Assignment.left = transfer_left_idx;
        transfer_stmt.Assignment.value = transfer_value_idx;
        transfer_stmt.Assignment.span = span_transfer;
    }
    mut transfer_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(transfer_stmt_idx, transfer_stmt);
    typechecker.check_statement(transfer_stmt_idx, &env_transfer, scope_transfer, ctx);

    if typechecker.env_open_linear_resource_is_moved(&env_transfer, "source_transfer_resource", ctx) != 1 {
        os.LogStr("Error: Resource-to-Resource assignment did not mark source as moved");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_transfer, "target_transfer_resource", ctx) != 1 {
        os.LogStr("Error: Resource-to-Resource assignment did not leave destination owned/open");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_transfer, "target_transfer_resource", ctx), "close_transfer_payload") == 0 {
        os.LogStr("Error: Resource-to-Resource move assignment did not preserve destination destructor identity");
        os.Exit(1);
    }

    mut self_left_transfer: ast.Expression[ctx];
    unsafe {
        self_left_transfer.tag = 0; // Identifier
        self_left_transfer.Identifier.name = "target_transfer_resource";
        self_left_transfer.Identifier.span = span_transfer;
    }
    mut self_left_idx_transfer: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(self_left_idx_transfer, self_left_transfer);

    mut self_value_transfer: ast.Expression[ctx];
    unsafe {
        self_value_transfer.tag = 0; // Identifier
        self_value_transfer.Identifier.name = "target_transfer_resource";
        self_value_transfer.Identifier.span = span_transfer;
    }
    mut self_value_idx_transfer: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(self_value_idx_transfer, self_value_transfer);

    mut self_transfer_stmt: ast.Statement[ctx];
    unsafe {
        self_transfer_stmt.tag = 5; // Assignment
        self_transfer_stmt.Assignment.left = self_left_idx_transfer;
        self_transfer_stmt.Assignment.value = self_value_idx_transfer;
        self_transfer_stmt.Assignment.span = span_transfer;
    }
    mut self_transfer_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(self_transfer_stmt_idx, self_transfer_stmt);
    typechecker.check_statement(self_transfer_stmt_idx, &env_transfer, scope_transfer, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_transfer, "target_transfer_resource", ctx) != 1 {
        os.LogStr("Error: Resource self-assignment must keep destination owned/open");
        os.Exit(1);
    }

    mut plain_payload_transfer := typechecker.make_type_struct("main__TransferPlainPayload", "", ctx);
    mut plain_resource_transfer := typechecker.make_type_resource(plain_payload_transfer, ctx);
    typechecker.scope_insert(scope_transfer, "plain_transfer_source", plain_resource_transfer, ctx);
    env_transfer.variable_types.Insert(std.Clone(ctx, "plain_transfer_source"), plain_resource_transfer);
    typechecker.scope_insert(scope_transfer, "plain_transfer_target", plain_resource_transfer, ctx);
    env_transfer.variable_types.Insert(std.Clone(ctx, "plain_transfer_target"), plain_resource_transfer);

    mut plain_left_transfer: ast.Expression[ctx];
    unsafe {
        plain_left_transfer.tag = 0; // Identifier
        plain_left_transfer.Identifier.name = "plain_transfer_target";
        plain_left_transfer.Identifier.span = span_transfer;
    }
    mut plain_left_idx_transfer: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_left_idx_transfer, plain_left_transfer);

    mut plain_value_transfer: ast.Expression[ctx];
    unsafe {
        plain_value_transfer.tag = 0; // Identifier
        plain_value_transfer.Identifier.name = "plain_transfer_source";
        plain_value_transfer.Identifier.span = span_transfer;
    }
    mut plain_value_idx_transfer: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_value_idx_transfer, plain_value_transfer);

    mut plain_stmt_transfer: ast.Statement[ctx];
    unsafe {
        plain_stmt_transfer.tag = 5; // Assignment
        plain_stmt_transfer.Assignment.left = plain_left_idx_transfer;
        plain_stmt_transfer.Assignment.value = plain_value_idx_transfer;
        plain_stmt_transfer.Assignment.span = span_transfer;
    }
    mut plain_stmt_idx_transfer: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_stmt_idx_transfer, plain_stmt_transfer);
    typechecker.check_statement(plain_stmt_idx_transfer, &env_transfer, scope_transfer, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_transfer, "plain_transfer_source", ctx) != 0 {
        os.LogStr("Error: non-tracking Resource payload source must not be moved");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_transfer, "plain_transfer_target", ctx) != 0 {
        os.LogStr("Error: non-tracking Resource payload destination must not be opened");
        os.Exit(1);
    }

    if len(env_transfer.errors) != 0 {
        os.LogStr("Error: Resource-to-Resource move assignment transfer produced unexpected typechecker error");
        os.LogStr(env_transfer.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource-to-Resource move assignment transfer verified!");
}
