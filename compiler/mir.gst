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

// Phase 7 metadata vocabulary only.
//
// These tags intentionally do not attach to MirProgram, MirFunction, MirBlock,
// MirLocal, MirStmt, MirValue, or MirTerminator yet. Later Phase 7 steps will
// add explicit metadata side tables and fixtures. This step only reserves the
// stable debug vocabulary for resource/provenance/native-boundary metadata.
type MirResourceKind enum {
    NonResource,
    LinearResource,
    DirectoryResource,
    NativeHandleResource
}

type MirResourceState enum {
    Untracked,
    Owned,
    Borrowed,
    Moved,
    Closed,
    DestructorScheduled
}

type MirProvenanceKind enum {
    Unknown,
    LocalBinding,
    Parameter,
    ReturnValue,
    NativeBoundary,
    ResourceDestructor
}

type MirNativeBoundaryKind enum {
    NotNativeBoundary,
    RuntimeCall,
    ExternFunction,
    UnsafeNativeCall,
    LayoutSensitiveCall
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

func mir_debug_resource_kind(kind: MirResourceKind) str {
    if kind.tag == 0 {
        return "MirResourceKind.NonResource";
    }
    if kind.tag == 1 {
        return "MirResourceKind.LinearResource";
    }
    if kind.tag == 2 {
        return "MirResourceKind.DirectoryResource";
    }
    if kind.tag == 3 {
        return "MirResourceKind.NativeHandleResource";
    }
    return "MirResourceKind.<unknown>";
}

func mir_debug_resource_state(state: MirResourceState) str {
    if state.tag == 0 {
        return "MirResourceState.Untracked";
    }
    if state.tag == 1 {
        return "MirResourceState.Owned";
    }
    if state.tag == 2 {
        return "MirResourceState.Borrowed";
    }
    if state.tag == 3 {
        return "MirResourceState.Moved";
    }
    if state.tag == 4 {
        return "MirResourceState.Closed";
    }
    if state.tag == 5 {
        return "MirResourceState.DestructorScheduled";
    }
    return "MirResourceState.<unknown>";
}

func mir_debug_provenance_kind(kind: MirProvenanceKind) str {
    if kind.tag == 0 {
        return "MirProvenanceKind.Unknown";
    }
    if kind.tag == 1 {
        return "MirProvenanceKind.LocalBinding";
    }
    if kind.tag == 2 {
        return "MirProvenanceKind.Parameter";
    }
    if kind.tag == 3 {
        return "MirProvenanceKind.ReturnValue";
    }
    if kind.tag == 4 {
        return "MirProvenanceKind.NativeBoundary";
    }
    if kind.tag == 5 {
        return "MirProvenanceKind.ResourceDestructor";
    }
    return "MirProvenanceKind.<unknown>";
}

func mir_debug_native_boundary_kind(kind: MirNativeBoundaryKind) str {
    if kind.tag == 0 {
        return "MirNativeBoundaryKind.NotNativeBoundary";
    }
    if kind.tag == 1 {
        return "MirNativeBoundaryKind.RuntimeCall";
    }
    if kind.tag == 2 {
        return "MirNativeBoundaryKind.ExternFunction";
    }
    if kind.tag == 3 {
        return "MirNativeBoundaryKind.UnsafeNativeCall";
    }
    if kind.tag == 4 {
        return "MirNativeBoundaryKind.LayoutSensitiveCall";
    }
    return "MirNativeBoundaryKind.<unknown>";
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

func mir_lower_conditional_branch_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 6 fixture-only conditional branch lowering.
    //
    // This represents the constrained MIR shape:
    //
    //   block0: branch true-ish condition ? block1 : block2
    //   block1: return 1
    //   block2: return 2
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut condition_value := mir_make_value_int_literal(1, "bool", span, ctx);
    mut condition_value_idx := mir_alloc_value(condition_value, ctx);
    mut branch_terminator := mir_make_terminator_branch(condition_value_idx, 1, 2, span);
    mut branch_terminator_idx := mir_alloc_terminator(branch_terminator, ctx);
    mut entry_block := mir_make_block(0, branch_terminator_idx, span, ctx);

    mut then_return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut then_return_value_idx := mir_alloc_value(then_return_value, ctx);
    mut then_terminator := mir_make_terminator_return(then_return_value_idx, span);
    mut then_terminator_idx := mir_alloc_terminator(then_terminator, ctx);
    mut then_block := mir_make_block(1, then_terminator_idx, span, ctx);

    mut else_return_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut else_return_value_idx := mir_alloc_value(else_return_value, ctx);
    mut else_terminator := mir_make_terminator_return(else_return_value_idx, span);
    mut else_terminator_idx := mir_alloc_terminator(else_terminator, ctx);
    mut else_block := mir_make_block(2, else_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_conditional_branch", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    blocks.Push(then_block);
    blocks.Push(else_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_block_jump_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 6 fixture-only unconditional block-jump lowering.
    //
    // This represents the constrained MIR shape:
    //
    //   block0: jump block1
    //   block1: return 1
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut jump_terminator := mir_make_terminator_jump(1, span, ctx);
    mut jump_terminator_idx := mir_alloc_terminator(jump_terminator, ctx);
    mut entry_block := mir_make_block(0, jump_terminator_idx, span, ctx);

    mut return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut return_value_idx := mir_alloc_value(return_value, ctx);
    mut return_terminator := mir_make_terminator_return(return_value_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut return_block := mir_make_block(1, return_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_block_jump", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    blocks.Push(return_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_local_binding_read_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 5 feature-migration fixture-only local binding/read lowering.
    //
    // This represents the constrained source shape:
    //
    //   func tiny_local_binding_read() int {
    //       mut value := 2;
    //       return value;
    //   }
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut initial_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut initial_value_idx := mir_alloc_value(initial_value, ctx);
    mut local_set := mir_make_stmt_local_set(0, initial_value_idx, span);

    mut local_read := mir_make_value_local_read(0, "int", span, ctx);
    mut local_read_idx := mir_alloc_value(local_read, ctx);
    mut return_terminator := mir_make_terminator_return(local_read_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
    statements.Push(local_set);
    ctx.Set(entry_block.statements, statements);

    mut function := mir_make_function("tiny_local_binding_read", "int", span, ctx);
    mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
    locals.Push(mir_make_local(0, "value", "int", span, ctx));
    ctx.Set(function.locals, locals);

    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_to_c_tiny_fixture(program: MirProgram[ctx], ctx: &Arena) str {
    // Phase 4 fixture-only MIR-to-C entry point.
    //
    // This is not wired into parser, typechecker, verifier, normal C emission,
    // native backend emission, or the production compiler path. Step 4 emits
    // only the tiny function-shell, tiny return-int-literal, and tiny
    // local-binding/read shapes. It does not emit params, calls, branches,
    // loops, or real AST-lowered programs yet.
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) == 1 {
        mut function := functions[0];
        if std.str_eq(function.name, "tiny_shell") != 0 {
            if std.str_eq(function.return_type, "void") != 0 {
                return "void tiny_shell(void) { return; }";
            }
        }

        if std.str_eq(function.name, "tiny_return_int") != 0 {
            if std.str_eq(function.return_type, "int") != 0 {
                mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
                if len(blocks) == 1 {
                    mut block := blocks[0];
                    mut terminator: MirTerminator[ctx] := ctx[block.terminator];
                    if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") != 0 {
                        unsafe {
                            mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
                            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.IntLiteral") != 0 {
                                if return_value.IntLiteral.val == 1 {
                                    if std.str_eq(return_value.IntLiteral.value_type, "int") != 0 {
                                        return "int tiny_return_int(void) { return 1; }";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if std.str_eq(function.name, "tiny_conditional_branch") != 0 {
            if std.str_eq(function.return_type, "int") != 0 {
                mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
                if len(locals) == 0 {
                    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
                    if len(blocks) == 3 {
                        mut entry_block := blocks[0];
                        mut then_block := blocks[1];
                        mut else_block := blocks[2];
                        if entry_block.id == 0 {
                            if then_block.id == 1 {
                                if else_block.id == 2 {
                                    mut entry_statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
                                    mut then_statements: std.Vector[MirStmt[ctx], ctx] := ctx[then_block.statements];
                                    mut else_statements: std.Vector[MirStmt[ctx], ctx] := ctx[else_block.statements];
                                    if len(entry_statements) == 0 {
                                        if len(then_statements) == 0 {
                                            if len(else_statements) == 0 {
                                                mut entry_terminator: MirTerminator[ctx] := ctx[entry_block.terminator];
                                                mut then_terminator: MirTerminator[ctx] := ctx[then_block.terminator];
                                                mut else_terminator: MirTerminator[ctx] := ctx[else_block.terminator];
                                                if std.str_eq(mir_debug_terminator_kind(entry_terminator), "MirTerminator.Branch") != 0 {
                                                    if std.str_eq(mir_debug_terminator_kind(then_terminator), "MirTerminator.Return") != 0 {
                                                        if std.str_eq(mir_debug_terminator_kind(else_terminator), "MirTerminator.Return") != 0 {
                                                            unsafe {
                                                                if entry_terminator.Branch.then_block == 1 {
                                                                    if entry_terminator.Branch.else_block == 2 {
                                                                        mut condition_value: MirValue[ctx] := ctx[entry_terminator.Branch.condition];
                                                                        mut then_value: MirValue[ctx] := ctx[then_terminator.Return.value];
                                                                        mut else_value: MirValue[ctx] := ctx[else_terminator.Return.value];
                                                                        if std.str_eq(mir_debug_value_kind(condition_value), "MirValue.IntLiteral") != 0 {
                                                                            if std.str_eq(mir_debug_value_kind(then_value), "MirValue.IntLiteral") != 0 {
                                                                                if std.str_eq(mir_debug_value_kind(else_value), "MirValue.IntLiteral") != 0 {
                                                                                    if condition_value.IntLiteral.val == 1 {
                                                                                        if then_value.IntLiteral.val == 1 {
                                                                                            if else_value.IntLiteral.val == 2 {
                                                                                                if std.str_eq(condition_value.IntLiteral.value_type, "bool") != 0 {
                                                                                                    if std.str_eq(then_value.IntLiteral.value_type, "int") != 0 {
                                                                                                        if std.str_eq(else_value.IntLiteral.value_type, "int") != 0 {
                                                                                                            return "int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }";
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if std.str_eq(function.name, "tiny_block_jump") != 0 {
            if std.str_eq(function.return_type, "int") != 0 {
                mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
                if len(locals) == 0 {
                    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
                    if len(blocks) == 2 {
                        mut entry_block := blocks[0];
                        mut return_block := blocks[1];
                        if entry_block.id == 0 {
                            if return_block.id == 1 {
                                mut entry_statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
                                mut return_statements: std.Vector[MirStmt[ctx], ctx] := ctx[return_block.statements];
                                if len(entry_statements) == 0 {
                                    if len(return_statements) == 0 {
                                        mut entry_terminator: MirTerminator[ctx] := ctx[entry_block.terminator];
                                        mut return_terminator: MirTerminator[ctx] := ctx[return_block.terminator];
                                        if std.str_eq(mir_debug_terminator_kind(entry_terminator), "MirTerminator.Jump") != 0 {
                                            if std.str_eq(mir_debug_terminator_kind(return_terminator), "MirTerminator.Return") != 0 {
                                                unsafe {
                                                    if entry_terminator.Jump.target_block == 1 {
                                                        mut return_value: MirValue[ctx] := ctx[return_terminator.Return.value];
                                                        if std.str_eq(mir_debug_value_kind(return_value), "MirValue.IntLiteral") != 0 {
                                                            if return_value.IntLiteral.val == 1 {
                                                                if std.str_eq(return_value.IntLiteral.value_type, "int") != 0 {
                                                                    return "int tiny_block_jump(void) { goto block_1; block_1: return 1; }";
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if std.str_eq(function.name, "tiny_local_binding_read") != 0 {
            if std.str_eq(function.return_type, "int") != 0 {
                mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
                if len(locals) == 1 {
                    mut local := locals[0];
                    if local.id == 0 {
                        if std.str_eq(local.name, "value") != 0 {
                            if std.str_eq(local.local_type, "int") != 0 {
                                mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
                                if len(blocks) == 1 {
                                    mut block := blocks[0];
                                    mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[block.statements];
                                    if len(statements) == 1 {
                                        mut stmt := statements[0];
                                        if std.str_eq(mir_debug_stmt_kind(stmt), "MirStmt.LocalSet") != 0 {
                                            mut terminator: MirTerminator[ctx] := ctx[block.terminator];
                                            if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") != 0 {
                                                unsafe {
                                                    if stmt.LocalSet.local_id == 0 {
                                                        mut set_value: MirValue[ctx] := ctx[stmt.LocalSet.value];
                                                        if std.str_eq(mir_debug_value_kind(set_value), "MirValue.IntLiteral") != 0 {
                                                            if set_value.IntLiteral.val == 2 {
                                                                if std.str_eq(set_value.IntLiteral.value_type, "int") != 0 {
                                                                    mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
                                                                    if std.str_eq(mir_debug_value_kind(return_value), "MirValue.LocalRead") != 0 {
                                                                        if return_value.LocalRead.local_id == 0 {
                                                                            if std.str_eq(return_value.LocalRead.value_type, "int") != 0 {
                                                                                return "int tiny_local_binding_read(void) { int value = 2; return value; }";
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return "/* gust MIR-to-C tiny fixture */";
}
