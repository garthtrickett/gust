// Gust MIR scaffold.
//
// MIR is the lowered executable IR between the typechecked AST and backend
// emission. Phase 1 is intentionally inert: this file defines the future home
// for MIR data structures, but no production compiler path should depend on it
// yet.
//
// Planned pipeline:
//
//   typechecked AST / typed high-level representation
//     -> Gust MIR
//     -> MIR verifier
//     -> C backend first
//     -> Crane lift backend later
//
// Phase 1 rule:
//   Do not add AST-to-MIR lowering, MIR-to-C emission, Crane lift integration,
//   or production codegen dependencies in this file yet.

import "token.gst" as token;

type MirProgram[ctx] struct {
    functions: Index[std.Vector[MirFunction[ctx], ctx], ctx]
}

type MirFunction[ctx] struct {
    name: str,
    params: Index[std.Vector[MirLocal[ctx], ctx], ctx],
    return_type: str,
    locals: Index[std.Vector[MirLocal[ctx], ctx], ctx],
    blocks: Index[std.Vector[MirBlock[ctx], ctx], ctx],
    entry_block: int,
    span: token.Span
}

type MirBlock[ctx] struct {
    id: int,
    statements: Index[std.Vector[MirStmt[ctx], ctx], ctx],
    terminator: Index[MirTerminator[ctx], ctx],
    span: token.Span
}

type MirLocal[ctx] struct {
    id: int,
    name: str,
    local_type: str,
    span: token.Span
}

type MirStmt[ctx] enum {
    Nop {
        span: token.Span
    },
    LocalSet {
        local_id: int,
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Expr {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    }
}

type MirValue[ctx] enum {
    IntLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    BoolLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    StringLiteral {
        val: str,
        value_type: str,
        span: token.Span
    },
    LocalRead {
        local_id: int,
        value_type: str,
        span: token.Span
    },
    Call {
        callee: str,
        args: Index[std.Vector[MirValue[ctx], ctx], ctx],
        value_type: str,
        span: token.Span
    }
}

type MirTerminator[ctx] enum {
    ReturnVoid {
        span: token.Span
    },
    Return {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Jump {
        target_block: int,
        span: token.Span
    },
    Branch {
        condition: Index[MirValue[ctx], ctx],
        then_block: int,
        else_block: int,
        span: token.Span
    }
}

func mir_make_empty_span() token.Span {
    mut span: token.Span;
    return span;
}

func mir_empty_function_vector(ctx: &Arena) Index[std.Vector[MirFunction[ctx], ctx], ctx] {
    mut functions: std.Vector[MirFunction[ctx], ctx] := std.VectorNew(ctx);
    mut functions_idx: Index[std.Vector[MirFunction[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(functions_idx, functions);
    return functions_idx;
}

func mir_empty_local_vector(ctx: &Arena) Index[std.Vector[MirLocal[ctx], ctx], ctx] {
    mut locals: std.Vector[MirLocal[ctx], ctx] := std.VectorNew(ctx);
    mut locals_idx: Index[std.Vector[MirLocal[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(locals_idx, locals);
    return locals_idx;
}

func mir_empty_block_vector(ctx: &Arena) Index[std.Vector[MirBlock[ctx], ctx], ctx] {
    mut blocks: std.Vector[MirBlock[ctx], ctx] := std.VectorNew(ctx);
    mut blocks_idx: Index[std.Vector[MirBlock[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(blocks_idx, blocks);
    return blocks_idx;
}

func mir_empty_stmt_vector(ctx: &Arena) Index[std.Vector[MirStmt[ctx], ctx], ctx] {
    mut statements: std.Vector[MirStmt[ctx], ctx] := std.VectorNew(ctx);
    mut statements_idx: Index[std.Vector[MirStmt[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(statements_idx, statements);
    return statements_idx;
}

func mir_empty_value_vector(ctx: &Arena) Index[std.Vector[MirValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirValue[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_alloc_value(value: MirValue[ctx], ctx: &Arena) Index[MirValue[ctx], ctx] {
    mut value_idx: Index[MirValue[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(value_idx, value);
    return value_idx;
}

func mir_alloc_terminator(terminator: MirTerminator[ctx], ctx: &Arena) Index[MirTerminator[ctx], ctx] {
    mut terminator_idx: Index[MirTerminator[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(terminator_idx, terminator);
    return terminator_idx;
}

func mir_make_program(ctx: &Arena) MirProgram[ctx] {
    mut program: MirProgram[ctx];
    program.functions = mir_empty_function_vector(ctx);
    return program;
}

func mir_make_function(name: str, return_type: str, span: token.Span, ctx: &Arena) MirFunction[ctx] {
    mut function: MirFunction[ctx];
    function.name = name;
    function.params = mir_empty_local_vector(ctx);
    function.return_type = return_type;
    function.locals = mir_empty_local_vector(ctx);
    function.blocks = mir_empty_block_vector(ctx);
    function.entry_block = 0;
    function.span = span;
    return function;
}

func mir_make_block(id: int, terminator: Index[MirTerminator[ctx], ctx], span: token.Span, ctx: &Arena) MirBlock[ctx] {
    mut block: MirBlock[ctx];
    block.id = id;
    block.statements = mir_empty_stmt_vector(ctx);
    block.terminator = terminator;
    block.span = span;
    return block;
}

func mir_make_local(id: int, name: str, local_type: str, span: token.Span, ctx: &Arena) MirLocal[ctx] {
    mut local: MirLocal[ctx];
    local.id = id;
    local.name = name;
    local.local_type = local_type;
    local.span = span;
    return local;
}

func mir_make_stmt_nop(span: token.Span, ctx: &Arena) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 0; // Nop
        stmt.Nop.span = span;
    }
    return stmt;
}

func mir_make_stmt_local_set(local_id: int, value: Index[MirValue[ctx], ctx], span: token.Span) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 1; // LocalSet
        stmt.LocalSet.local_id = local_id;
        stmt.LocalSet.value = value;
        stmt.LocalSet.span = span;
    }
    return stmt;
}

func mir_make_stmt_expr(value: Index[MirValue[ctx], ctx], span: token.Span) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 2; // Expr
        stmt.Expr.value = value;
        stmt.Expr.span = span;
    }
    return stmt;
}

func mir_make_value_int_literal(val: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 0; // IntLiteral
        value.IntLiteral.val = val;
        value.IntLiteral.value_type = value_type;
        value.IntLiteral.span = span;
    }
    return value;
}

func mir_make_value_bool_literal(val: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 1; // BoolLiteral
        value.BoolLiteral.val = val;
        value.BoolLiteral.value_type = value_type;
        value.BoolLiteral.span = span;
    }
    return value;
}

func mir_make_value_string_literal(val: str, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 2; // StringLiteral
        value.StringLiteral.val = val;
        value.StringLiteral.value_type = value_type;
        value.StringLiteral.span = span;
    }
    return value;
}

func mir_make_value_local_read(local_id: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 3; // LocalRead
        value.LocalRead.local_id = local_id;
        value.LocalRead.value_type = value_type;
        value.LocalRead.span = span;
    }
    return value;
}

func mir_make_value_call(callee: str, args: Index[std.Vector[MirValue[ctx], ctx], ctx], value_type: str, span: token.Span) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 4; // Call
        value.Call.callee = callee;
        value.Call.args = args;
        value.Call.value_type = value_type;
        value.Call.span = span;
    }
    return value;
}

func mir_make_terminator_return_void(span: token.Span, ctx: &Arena) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 0; // ReturnVoid
        terminator.ReturnVoid.span = span;
    }
    return terminator;
}

func mir_make_terminator_return(value: Index[MirValue[ctx], ctx], span: token.Span) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 1; // Return
        terminator.Return.value = value;
        terminator.Return.span = span;
    }
    return terminator;
}

func mir_make_terminator_jump(target_block: int, span: token.Span, ctx: &Arena) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 2; // Jump
        terminator.Jump.target_block = target_block;
        terminator.Jump.span = span;
    }
    return terminator;
}

func mir_make_terminator_branch(condition: Index[MirValue[ctx], ctx], then_block: int, else_block: int, span: token.Span) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 3; // Branch
        terminator.Branch.condition = condition;
        terminator.Branch.then_block = then_block;
        terminator.Branch.else_block = else_block;
        terminator.Branch.span = span;
    }
    return terminator;
}

func mir_debug_stmt_kind(stmt: MirStmt[ctx]) str {
    if stmt.tag == 0 {
        return "MirStmt.Nop";
    }
    if stmt.tag == 1 {
        return "MirStmt.LocalSet";
    }
    if stmt.tag == 2 {
        return "MirStmt.Expr";
    }
    return "MirStmt.<unknown>";
}

func mir_debug_value_kind(value: MirValue[ctx]) str {
    if value.tag == 0 {
        return "MirValue.IntLiteral";
    }
    if value.tag == 1 {
        return "MirValue.BoolLiteral";
    }
    if value.tag == 2 {
        return "MirValue.StringLiteral";
    }
    if value.tag == 3 {
        return "MirValue.LocalRead";
    }
    if value.tag == 4 {
        return "MirValue.Call";
    }
    return "MirValue.<unknown>";
}

func mir_debug_terminator_kind(terminator: MirTerminator[ctx]) str {
    if terminator.tag == 0 {
        return "MirTerminator.ReturnVoid";
    }
    if terminator.tag == 1 {
        return "MirTerminator.Return";
    }
    if terminator.tag == 2 {
        return "MirTerminator.Jump";
    }
    if terminator.tag == 3 {
        return "MirTerminator.Branch";
    }
    return "MirTerminator.<unknown>";
}

func mir_debug_print_program(program: MirProgram[ctx]) {
    os.LogStr("mir.program");
    os.LogStr("  functions");
}

func mir_debug_print_function(function: MirFunction[ctx]) {
    os.LogStr("mir.function");
    os.LogStr("  name");
    os.LogStr(function.name);
    os.LogStr("  return_type");
    os.LogStr(function.return_type);
    os.LogStr("  params");
    os.LogStr("  locals");
    os.LogStr("  blocks");
}

func mir_debug_print_block(block: MirBlock[ctx], ctx: &Arena) {
    os.LogStr("mir.block");
    os.LogStr("  terminator");
    os.LogStr(mir_debug_terminator_kind(ctx[block.terminator]));
}

func mir_debug_print_stmt(stmt: MirStmt[ctx]) {
    os.LogStr("mir.stmt");
    os.LogStr(mir_debug_stmt_kind(stmt));
}

func mir_debug_print_value(value: MirValue[ctx]) {
    os.LogStr("mir.value");
    os.LogStr(mir_debug_value_kind(value));
}

func mir_debug_print_terminator(terminator: MirTerminator[ctx]) {
    os.LogStr("mir.terminator");
    os.LogStr(mir_debug_terminator_kind(terminator));
}

func mir_lower_tiny_function_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 3 fixture-only lowering entry point.
    //
    // This is intentionally inert and is not wired into parser, typechecker,
    // verifier, C emission, Crane lift, or the production compiler path.
    // Step 2 lowers only a tiny function shell: one function, one empty entry
    // block, and a ReturnVoid terminator. It does not lower real AST,
    // expressions, locals, calls, branches, or statements yet.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut return_void := mir_make_terminator_return_void(span, ctx);
    mut return_void_idx := mir_alloc_terminator(return_void, ctx);
    mut entry_block := mir_make_block(0, return_void_idx, span, ctx);

    mut function := mir_make_function("tiny_shell", "void", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_return_int_literal_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 3 fixture-only tiny return-literal lowering.
    //
    // This represents the constrained source shape:
    //
    //   func tiny_return_int() int {
    //       return 1;
    //   }
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut return_value_idx := mir_alloc_value(return_value, ctx);
    mut return_terminator := mir_make_terminator_return(return_value_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_return_int", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}
