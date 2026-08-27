import "ast.gst" as ast;
import "codegen.gst" as codegen;
import "mir.gst" as mir;
import "typechecker.gst" as typechecker;

// Patch 21.14 full-program typed-input to canonical-MIR lowering.
//
// This lowerer is deliberately introduced signature-first. A program is not
// represented until every resolved function signature has one compiler-owned
// canonical type identity and one explicit Phase 16 ABI position. Executable
// body lowering is enabled only after the corresponding operation inventory is
// complete; until then this module returns a deterministic compiler-owned
// diagnostic before driver discovery and cannot publish an artifact.

type MirNativeFullProgramFunction[ctx] struct {
    module_index: int,
    source_name: str,
    qualified_name: str,
    is_extern: int,
    extern_symbol_name: str,
    parameter_names: Index[std.Vector[str, ctx], ctx],
    parameter_types: Index[std.Vector[str, ctx], ctx],
    return_type: str,
    body: Index[ast.BlockStatement[ctx], ctx],
    body_node_index: int
}

// Structured canonical MIR node. Source syntax has already been resolved and
// typechecked before these records are built. `kind` is the executable MIR
// operation family, `type_identity` is the resolved canonical value type, the
// text/integer payloads are kind-specific operands, and `children` contains
// post-order canonical node indices. No raw arena index or backend-created
// layout/ABI decision is serialized.
type MirNativeFullProgramNode[ctx] struct {
    kind: str,
    type_identity: str,
    text_operand: str,
    second_text_operand: str,
    integer_operand: int,
    second_integer_operand: int,
    source_line: int,
    source_column: int,
    source_start_offset: int,
    source_end_offset: int,
    children: Index[std.Vector[int, ctx], ctx]
}

type MirNativeFullProgramLayout[ctx] struct {
    name: str,
    erased_name: str,
    brand: str,
    is_repr_c: int,
    is_packed: int,
    layout_abi: str,
    field_names: Index[std.Vector[str, ctx], ctx],
    field_types: Index[std.Vector[str, ctx], ctx]
}

type MirNativeFullProgramEnum[ctx] struct {
    name: str,
    erased_name: str,
    variants: Index[std.Vector[str, ctx], ctx]
}

type MirNativeFullProgramModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    function_count: int,
    non_scalar_signature_count: int,
    entry_function_index: int,
    functions: Index[std.Vector[MirNativeFullProgramFunction[ctx], ctx], ctx],
    nodes: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx],
    layouts: Index[std.Vector[MirNativeFullProgramLayout[ctx], ctx], ctx],
    enums: Index[std.Vector[MirNativeFullProgramEnum[ctx], ctx], ctx]
}

type MirNativeFullProgramSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

type MirNativeFullProgramStringHeader struct {
    data: *byte,
    len: int
}

func mir_native_full_program_empty_string_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_function_vector(ctx: &Arena) Index[std.Vector[MirNativeFullProgramFunction[ctx], ctx], ctx] {
    mut values: std.Vector[MirNativeFullProgramFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut index: Index[std.Vector[MirNativeFullProgramFunction[ctx], ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_node_vector(ctx: &Arena) Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx] {
    mut values: std.Vector[MirNativeFullProgramNode[ctx], ctx] :=
        std.VectorNew(ctx);
    mut index: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_layout_vector(ctx: &Arena) Index[std.Vector[MirNativeFullProgramLayout[ctx], ctx], ctx] {
    mut values: std.Vector[MirNativeFullProgramLayout[ctx], ctx] :=
        std.VectorNew(ctx);
    mut index: Index[std.Vector[MirNativeFullProgramLayout[ctx], ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_enum_vector(ctx: &Arena) Index[std.Vector[MirNativeFullProgramEnum[ctx], ctx], ctx] {
    mut values: std.Vector[MirNativeFullProgramEnum[ctx], ctx] :=
        std.VectorNew(ctx);
    mut index: Index[std.Vector[MirNativeFullProgramEnum[ctx], ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_int_vector(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_full_program_empty_model(ctx: &Arena) MirNativeFullProgramModel[ctx] {
    mut model: MirNativeFullProgramModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.diagnostic = std.Clone(ctx, "");
    model.function_count = 0;
    model.non_scalar_signature_count = 0;
    model.entry_function_index = 0 - 1;
    model.functions = mir_native_full_program_empty_function_vector(ctx);
    model.nodes = mir_native_full_program_empty_node_vector(ctx);
    model.layouts = mir_native_full_program_empty_layout_vector(ctx);
    model.enums = mir_native_full_program_empty_enum_vector(ctx);
    return model;
}

func mir_native_full_program_invalid(model: MirNativeFullProgramModel[ctx], diagnostic: str, ctx: &Arena) MirNativeFullProgramModel[ctx] {
    mut invalid := model;
    invalid.represented = 1;
    invalid.invalid = 1;
    invalid.diagnostic = std.Clone(ctx, diagnostic);
    return invalid;
}

func mir_native_full_program_type_identity(value_type: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    mut resolved := typechecker.env_resolve_type(env, value_type, ctx);
    mut erased := codegen.codegen_erase_type(resolved, env, ctx);
    return std.Clone(ctx, ast.serialize_type(erased, ctx));
}

func mir_native_full_program_type_is_initial_scalar(value_type: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    mut resolved := typechecker.env_resolve_type(env, value_type, ctx);
    unsafe {
        if resolved.tag == 0 || resolved.tag == 2 || resolved.tag == 3 {
            return 1;
        }
    }
    return 0;
}

func mir_native_full_program_qualified_name(prefix: str, name: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(prefix, name));
}

func mir_native_full_program_make_node(kind: str, type_identity: str, text_operand: str, second_text_operand: str, integer_operand: int, second_integer_operand: int, source_line: int, source_column: int, source_start_offset: int, source_end_offset: int, ctx: &Arena) MirNativeFullProgramNode[ctx] {
    mut node: MirNativeFullProgramNode[ctx];
    node.kind = std.Clone(ctx, kind);
    node.type_identity = std.Clone(ctx, type_identity);
    node.text_operand = std.Clone(ctx, text_operand);
    node.second_text_operand = std.Clone(ctx, second_text_operand);
    node.integer_operand = integer_operand;
    node.second_integer_operand = second_integer_operand;
    node.source_line = source_line;
    node.source_column = source_column;
    node.source_start_offset = source_start_offset;
    node.source_end_offset = source_end_offset;
    node.children = mir_native_full_program_empty_int_vector(ctx);
    return node;
}

func mir_native_full_program_node_with_child(node: MirNativeFullProgramNode[ctx], child_index: int, ctx: &Arena) MirNativeFullProgramNode[ctx] {
    mut updated := node;
    mut children: std.Vector[int, ctx] := ctx[updated.children];
    children.Push(child_index);
    ctx.Set(updated.children, children);
    return updated;
}

func mir_native_full_program_push_node(nodes_index: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx], node: MirNativeFullProgramNode[ctx], ctx: &Arena) int {
    mut nodes: std.Vector[MirNativeFullProgramNode[ctx], ctx] :=
        ctx[nodes_index];
    mut index := len(nodes);
    nodes.Push(node);
    ctx.Set(nodes_index, nodes);
    return index;
}

func mir_native_full_program_expression_type_identity(expression_index: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    mut expression_type := codegen.codegen_get_expression_type(
        expression_index,
        env,
        ctx
    );
    mut identity := mir_native_full_program_type_identity(
        expression_type,
        env,
        ctx
    );
    return std.Clone(ctx, identity);
}

func mir_native_full_program_flatten_expression(expression_index: Index[ast.Expression[ctx], ctx], nodes_index: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    if expression_index == empty[Index[ast.Expression[ctx], ctx]] {
        return 0 - 1;
    }
    mut expression := ctx[expression_index];
    mut span := codegen.codegen_get_expression_span(expression_index, ctx);
    mut type_identity :=
        mir_native_full_program_expression_type_identity(
            expression_index,
            env,
            ctx
        );
    if len(type_identity) == 0 || std.str_eq(type_identity, "Unknown") == 1 {
        return 0 - 1;
    }
    mut node := mir_native_full_program_make_node(
        "Invalid",
        type_identity,
        "",
        "",
        0,
        0,
        span.start.line,
        span.start.column,
        span.start.offset,
        span.end.offset,
        ctx
    );

    unsafe {
        if expression.tag == 0 {
            node.kind = "LocalRead";
            node.text_operand = std.Clone(ctx, expression.Identifier.name);
        } else if expression.tag == 1 {
            node.kind = "IntegerLiteral";
            node.integer_operand = expression.Integer.val;
        } else if expression.tag == 2 {
            node.kind = "StringLiteral";
            node.text_operand = std.Clone(ctx, expression.String.val);
        } else if expression.tag == 3 {
            node.kind = "BooleanLiteral";
            node.integer_operand = expression.Bool.val;
        } else if expression.tag == 4 {
            node.kind = "MoveValue";
            mut child := mir_native_full_program_flatten_expression(
                expression.Move.expr, nodes_index, env, ctx
            );
            if child < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, child, ctx);
        } else if expression.tag == 5 {
            node.kind = "TakeValue";
            mut child := mir_native_full_program_flatten_expression(
                expression.Take.expr, nodes_index, env, ctx
            );
            if child < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, child, ctx);
        } else if expression.tag == 6 {
            node.kind = "AddressOf";
            mut child := mir_native_full_program_flatten_expression(
                expression.AddressOf.expr, nodes_index, env, ctx
            );
            if child < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, child, ctx);
        } else if expression.tag == 7 {
            node.kind = "Dereference";
            mut child := mir_native_full_program_flatten_expression(
                expression.Dereference.expr, nodes_index, env, ctx
            );
            if child < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, child, ctx);
        } else if expression.tag == 8 {
            node.kind = "IndexRead";
            mut allocator := mir_native_full_program_flatten_expression(
                expression.IndexAccess.allocator, nodes_index, env, ctx
            );
            mut index := mir_native_full_program_flatten_expression(
                expression.IndexAccess.index, nodes_index, env, ctx
            );
            if allocator < 0 || index < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, allocator, ctx);
            node = mir_native_full_program_node_with_child(node, index, ctx);
        } else if expression.tag == 9 {
            node.kind = "ExplicitCast";
            node.integer_operand = expression.AsCast.is_reference;
            node.text_operand = mir_native_full_program_type_identity(
                ctx[expression.AsCast.target_type], env, ctx
            );
            mut child := mir_native_full_program_flatten_expression(
                expression.AsCast.left, nodes_index, env, ctx
            );
            if child < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, child, ctx);
        } else if expression.tag == 10 {
            node.kind = "BinaryOperation";
            node.text_operand = std.Clone(ctx, expression.Binary.op);
            mut left := mir_native_full_program_flatten_expression(
                expression.Binary.left, nodes_index, env, ctx
            );
            mut right := mir_native_full_program_flatten_expression(
                expression.Binary.right, nodes_index, env, ctx
            );
            if left < 0 || right < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, left, ctx);
            node = mir_native_full_program_node_with_child(node, right, ctx);
        } else if expression.tag == 11 {
            node.kind = "FieldOrMethodSelect";
            node.text_operand = std.Clone(ctx, expression.Selector.right);
            mut receiver := mir_native_full_program_flatten_expression(
                expression.Selector.left, nodes_index, env, ctx
            );
            if receiver < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, receiver, ctx);
        } else if expression.tag == 12 {
            node.kind = "Call";
            mut raw_callee := typechecker.get_call_func_name(
                expression.Call.function, ctx
            );
            node.text_operand = std.Clone(ctx, raw_callee);
            node.second_text_operand = std.Clone(
                ctx,
                typechecker.env_resolve_namespaced_ident(
                    env, raw_callee, ctx
                )
            );
            mut callee := mir_native_full_program_flatten_expression(
                expression.Call.function, nodes_index, env, ctx
            );
            if callee < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, callee, ctx);
            mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[expression.Call.arguments];
            mut argument_index := 0;
            while argument_index < len(arguments) {
                mut argument_arena_index: Index[ast.Expression[ctx], ctx] :=
                    os.ArenaAlloc(ctx);
                ctx.Set(argument_arena_index, arguments[argument_index]);
                mut argument := mir_native_full_program_flatten_expression(
                    argument_arena_index, nodes_index, env, ctx
                );
                if argument < 0 { return 0 - 1; }
                node = mir_native_full_program_node_with_child(
                    node, argument, ctx
                );
                argument_index = argument_index + 1;
            }
        } else if expression.tag == 13 {
            node.kind = "ZeroInitialize";
            node.text_operand = mir_native_full_program_type_identity(
                ctx[expression.Empty.target_type], env, ctx
            );
        } else if expression.tag == 14 {
            // Query semantics have already been validated by the compiler.
            // Preserve every executable child rather than re-running scope
            // authority in the backend.
            node.kind = "TypedQueryValue";
            mut predicates: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[expression.Query.predicates];
            mut predicate_index := 0;
            while predicate_index < len(predicates) {
                mut predicate_arena_index: Index[ast.Expression[ctx], ctx] :=
                    os.ArenaAlloc(ctx);
                ctx.Set(predicate_arena_index, predicates[predicate_index]);
                mut predicate := mir_native_full_program_flatten_expression(
                    predicate_arena_index, nodes_index, env, ctx
                );
                if predicate < 0 { return 0 - 1; }
                node = mir_native_full_program_node_with_child(
                    node, predicate, ctx
                );
                predicate_index = predicate_index + 1;
            }
            mut terminal := mir_native_full_program_flatten_expression(
                expression.Query.terminal, nodes_index, env, ctx
            );
            if terminal < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, terminal, ctx);
        } else {
            return 0 - 1;
        }
    }
    return mir_native_full_program_push_node(nodes_index, node, ctx);
}

func mir_native_full_program_flatten_block(block_index: Index[ast.BlockStatement[ctx], ctx], nodes_index: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    if block_index == empty[Index[ast.BlockStatement[ctx], ctx]] {
        return 0 - 1;
    }
    mut block := ctx[block_index];
    mut node := mir_native_full_program_make_node(
        "Block",
        "Void",
        "",
        "",
        0,
        0,
        block.span.start.line,
        block.span.start.column,
        block.span.start.offset,
        block.span.end.offset,
        ctx
    );
    mut statements: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[block.statements];
    mut statement_index := 0;
    while statement_index < len(statements) {
        mut child := mir_native_full_program_flatten_statement(
            statements[statement_index],
            nodes_index,
            env,
            ctx
        );
        if child < 0 { return 0 - 1; }
        node = mir_native_full_program_node_with_child(node, child, ctx);
        statement_index = statement_index + 1;
    }
    return mir_native_full_program_push_node(nodes_index, node, ctx);
}

func mir_native_full_program_flatten_statement(statement: ast.Statement[ctx], nodes_index: Index[std.Vector[MirNativeFullProgramNode[ctx], ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    mut kind := std.Clone(ctx, "Invalid");
    mut text_operand := std.Clone(ctx, "");
    mut second_text_operand := std.Clone(ctx, "");
    mut integer_operand := 0;
    mut second_integer_operand := 0;
    mut source_line := 0;
    mut source_column := 0;
    mut source_start_offset := 0;
    mut source_end_offset := 0;
    mut type_identity := std.Clone(ctx, "Void");

    unsafe {
        if statement.tag == 4 {
            kind = "LocalDeclare";
            text_operand = std.Clone(ctx, statement.VarDecl.name);
            integer_operand = statement.VarDecl.is_mut;
            source_line = statement.VarDecl.span.start.line;
            source_column = statement.VarDecl.span.start.column;
            source_start_offset = statement.VarDecl.span.start.offset;
            source_end_offset = statement.VarDecl.span.end.offset;
            if statement.VarDecl.var_type != empty[Index[ast.Type[ctx], ctx]] {
                type_identity = mir_native_full_program_type_identity(
                    ctx[statement.VarDecl.var_type], env, ctx
                );
            } else if statement.VarDecl.value !=
                      empty[Index[ast.Expression[ctx], ctx]] {
                type_identity =
                    mir_native_full_program_expression_type_identity(
                        statement.VarDecl.value, env, ctx
                    );
            }
        } else if statement.tag == 5 {
            kind = "Assign";
            source_line = statement.Assignment.span.start.line;
            source_column = statement.Assignment.span.start.column;
            source_start_offset = statement.Assignment.span.start.offset;
            source_end_offset = statement.Assignment.span.end.offset;
        } else if statement.tag == 6 {
            kind = "Loop";
            source_line = statement.While.span.start.line;
            source_column = statement.While.span.start.column;
            source_start_offset = statement.While.span.start.offset;
            source_end_offset = statement.While.span.end.offset;
        } else if statement.tag == 7 {
            kind = "Branch";
            source_line = statement.If.span.start.line;
            source_column = statement.If.span.start.column;
            source_start_offset = statement.If.span.start.offset;
            source_end_offset = statement.If.span.end.offset;
        } else if statement.tag == 8 {
            kind = "EnumMatch";
            source_line = statement.Match.span.start.line;
            source_column = statement.Match.span.start.column;
            source_start_offset = statement.Match.span.start.offset;
            source_end_offset = statement.Match.span.end.offset;
        } else if statement.tag == 9 {
            kind = "GuardUnwrap";
            text_operand = std.Clone(ctx, statement.Guard.name);
            integer_operand = statement.Guard.is_mut;
            source_line = statement.Guard.span.start.line;
            source_column = statement.Guard.span.start.column;
            source_start_offset = statement.Guard.span.start.offset;
            source_end_offset = statement.Guard.span.end.offset;
        } else if statement.tag == 10 {
            kind = "UnsafeScope";
            source_line = statement.UnsafeBlock.span.start.line;
            source_column = statement.UnsafeBlock.span.start.column;
            source_start_offset = statement.UnsafeBlock.span.start.offset;
            source_end_offset = statement.UnsafeBlock.span.end.offset;
        } else if statement.tag == 11 {
            kind = "ScheduleDefer";
            source_line = statement.Defer.span.start.line;
            source_column = statement.Defer.span.start.column;
            source_start_offset = statement.Defer.span.start.offset;
            source_end_offset = statement.Defer.span.end.offset;
        } else if statement.tag == 12 {
            kind = "Return";
            source_line = statement.Return.span.start.line;
            source_column = statement.Return.span.start.column;
            source_start_offset = statement.Return.span.start.offset;
            source_end_offset = statement.Return.span.end.offset;
        } else if statement.tag == 13 {
            kind = "Evaluate";
            source_line = statement.Expression.span.start.line;
            source_column = statement.Expression.span.start.column;
            source_start_offset = statement.Expression.span.start.offset;
            source_end_offset = statement.Expression.span.end.offset;
        } else {
            // Imports and type/function declarations are represented by the
            // module, layout, and function tables rather than executable body
            // nodes. They are not valid inside a function block.
            return 0 - 1;
        }
    }

    mut node := mir_native_full_program_make_node(
        kind,
        type_identity,
        text_operand,
        second_text_operand,
        integer_operand,
        second_integer_operand,
        source_line,
        source_column,
        source_start_offset,
        source_end_offset,
        ctx
    );

    unsafe {
        if statement.tag == 4 {
            if statement.VarDecl.value != empty[Index[ast.Expression[ctx], ctx]] {
                mut value := mir_native_full_program_flatten_expression(
                    statement.VarDecl.value, nodes_index, env, ctx
                );
                if value < 0 { return 0 - 1; }
                node = mir_native_full_program_node_with_child(node, value, ctx);
            }
        } else if statement.tag == 5 {
            mut destination := mir_native_full_program_flatten_expression(
                statement.Assignment.left, nodes_index, env, ctx
            );
            mut value := mir_native_full_program_flatten_expression(
                statement.Assignment.value, nodes_index, env, ctx
            );
            if destination < 0 || value < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(
                node, destination, ctx
            );
            node = mir_native_full_program_node_with_child(node, value, ctx);
        } else if statement.tag == 6 {
            mut condition := mir_native_full_program_flatten_expression(
                statement.While.condition, nodes_index, env, ctx
            );
            mut body := mir_native_full_program_flatten_block(
                statement.While.body, nodes_index, env, ctx
            );
            if condition < 0 || body < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, condition, ctx);
            node = mir_native_full_program_node_with_child(node, body, ctx);
        } else if statement.tag == 7 {
            mut condition := mir_native_full_program_flatten_expression(
                statement.If.condition, nodes_index, env, ctx
            );
            mut consequence := mir_native_full_program_flatten_block(
                statement.If.consequence, nodes_index, env, ctx
            );
            if condition < 0 || consequence < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, condition, ctx);
            node = mir_native_full_program_node_with_child(
                node, consequence, ctx
            );
            if statement.If.alternative !=
               empty[Index[ast.BlockStatement[ctx], ctx]] {
                mut alternative := mir_native_full_program_flatten_block(
                    statement.If.alternative, nodes_index, env, ctx
                );
                if alternative < 0 { return 0 - 1; }
                node = mir_native_full_program_node_with_child(
                    node, alternative, ctx
                );
            }
        } else if statement.tag == 8 {
            mut subject := mir_native_full_program_flatten_expression(
                statement.Match.expression, nodes_index, env, ctx
            );
            if subject < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, subject, ctx);
            mut cases: std.Vector[ast.MatchCase[ctx], ctx] :=
                ctx[statement.Match.cases];
            mut case_index := 0;
            while case_index < len(cases) {
                mut case_value := cases[case_index];
                mut arm := mir_native_full_program_make_node(
                    "EnumMatchArm", "Void", case_value.variant_name, "",
                    case_index, 0, case_value.span.start.line,
                    case_value.span.start.column, case_value.span.start.offset,
                    case_value.span.end.offset, ctx
                );
                mut bindings: std.Vector[str, ctx] := ctx[case_value.fields];
                mut binding_index := 0;
                while binding_index < len(bindings) {
                    mut binding := mir_native_full_program_make_node(
                        "EnumPayloadBinding", "", bindings[binding_index],
                        case_value.variant_name, binding_index, 0,
                        case_value.span.start.line,
                        case_value.span.start.column,
                        case_value.span.start.offset,
                        case_value.span.end.offset, ctx
                    );
                    mut binding_node := mir_native_full_program_push_node(
                        nodes_index, binding, ctx
                    );
                    arm = mir_native_full_program_node_with_child(
                        arm, binding_node, ctx
                    );
                    binding_index = binding_index + 1;
                }
                mut body := mir_native_full_program_flatten_block(
                    case_value.body, nodes_index, env, ctx
                );
                if body < 0 { return 0 - 1; }
                arm = mir_native_full_program_node_with_child(arm, body, ctx);
                mut arm_node := mir_native_full_program_push_node(
                    nodes_index, arm, ctx
                );
                node = mir_native_full_program_node_with_child(
                    node, arm_node, ctx
                );
                case_index = case_index + 1;
            }
        } else if statement.tag == 9 {
            mut value := mir_native_full_program_flatten_expression(
                statement.Guard.value, nodes_index, env, ctx
            );
            mut else_body := mir_native_full_program_flatten_block(
                statement.Guard.else_body, nodes_index, env, ctx
            );
            if value < 0 || else_body < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, value, ctx);
            node = mir_native_full_program_node_with_child(
                node, else_body, ctx
            );
        } else if statement.tag == 10 {
            mut body := mir_native_full_program_flatten_block(
                statement.UnsafeBlock.body, nodes_index, env, ctx
            );
            if body < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, body, ctx);
        } else if statement.tag == 11 {
            mut deferred := mir_native_full_program_flatten_expression(
                statement.Defer.expr, nodes_index, env, ctx
            );
            if deferred < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, deferred, ctx);
        } else if statement.tag == 12 {
            if statement.Return.expr != empty[Index[ast.Expression[ctx], ctx]] {
                mut value := mir_native_full_program_flatten_expression(
                    statement.Return.expr, nodes_index, env, ctx
                );
                if value < 0 { return 0 - 1; }
                node = mir_native_full_program_node_with_child(node, value, ctx);
            }
        } else if statement.tag == 13 {
            mut value := mir_native_full_program_flatten_expression(
                statement.Expression.expr, nodes_index, env, ctx
            );
            if value < 0 { return 0 - 1; }
            node = mir_native_full_program_node_with_child(node, value, ctx);
        }
    }
    return mir_native_full_program_push_node(nodes_index, node, ctx);
}

func mir_native_full_program_function_index(functions: std.Vector[MirNativeFullProgramFunction[ctx], ctx], qualified_name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(functions) {
        if std.str_eq(functions[index].qualified_name, qualified_name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_full_program_collect_layout_authority(model: MirNativeFullProgramModel[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) MirNativeFullProgramModel[ctx] {
    mut updated := model;
    unsafe {
        mut layouts: std.Vector[MirNativeFullProgramLayout[ctx], ctx] :=
            std.VectorNew(ctx);
        mut layout_names := typechecker.typechecker_get_sorted_keys_layout(
            &(*env).struct_registry, ctx
        );
        mut layout_index := 0;
        while layout_index < len(layout_names) {
            mut name := layout_names[layout_index];
            guard registry_layout := (*env).struct_registry.Get(name) else {
                return mir_native_full_program_invalid(
                    updated,
                    "Native backend canonical MIR verification failed: full-program layout registry changed during canonicalization",
                    ctx
                );
            };
            mut value: MirNativeFullProgramLayout[ctx];
            value.name = std.Clone(ctx, name);
            value.erased_name = codegen.codegen_get_erased_struct_name(
                name, env, ctx
            );
            value.brand = std.Clone(ctx, "");
            if registry_layout.brand != empty[Index[str, ctx]] {
                value.brand = std.Clone(ctx, ctx[registry_layout.brand]);
            }
            value.is_repr_c = 0;
            mut repr_lookup := (*env).struct_layout_repr_c.Get(name);
            if repr_lookup.Ok { value.is_repr_c = repr_lookup.Val; }
            value.is_packed = 0;
            mut packed_lookup := (*env).struct_layout_packed.Get(name);
            if packed_lookup.Ok { value.is_packed = packed_lookup.Val; }
            value.layout_abi = std.Clone(ctx, "");
            mut abi_lookup := (*env).struct_layout_abi.Get(name);
            if abi_lookup.Ok {
                value.layout_abi = std.Clone(ctx, abi_lookup.Val);
            }
            value.field_names = mir_native_full_program_empty_string_vector(ctx);
            value.field_types = mir_native_full_program_empty_string_vector(ctx);
            mut field_names := typechecker.typechecker_get_sorted_keys_type(
                &registry_layout.fields, ctx
            );
            // These retained-C structures are deliberately owned by
            // core_headers.h and omitted from generated C declarations.  The
            // canonical native layout must therefore preserve that existing
            // boundary order rather than the compiler's normal deterministic
            // alphabetical declaration order.
            if std.str_eq(value.erased_name, "std_Vector_str") == 1 {
                mut retained_vector_fields: std.Vector[str, ctx] :=
                    std.VectorNew(ctx);
                retained_vector_fields.Push(std.Clone(ctx, "data"));
                retained_vector_fields.Push(std.Clone(ctx, "len"));
                retained_vector_fields.Push(std.Clone(ctx, "capacity"));
                retained_vector_fields.Push(std.Clone(ctx, "arena"));
                field_names = retained_vector_fields;
                value.layout_abi = std.Clone(ctx, "retained_c_runtime");
            } else if std.str_eq(value.erased_name, "os_ProcessResult") == 1 {
                mut retained_process_fields: std.Vector[str, ctx] :=
                    std.VectorNew(ctx);
                retained_process_fields.Push(std.Clone(ctx, "status"));
                retained_process_fields.Push(std.Clone(ctx, "stdout_text"));
                retained_process_fields.Push(std.Clone(ctx, "stderr_text"));
                field_names = retained_process_fields;
                value.layout_abi = std.Clone(ctx, "retained_c_runtime");
            }
            mut field_types: std.Vector[str, ctx] := std.VectorNew(ctx);
            mut field_index := 0;
            while field_index < len(field_names) {
                guard field_type := registry_layout.fields.Get(
                    field_names[field_index]
                ) else {
                    return mir_native_full_program_invalid(
                        updated,
                        "Native backend canonical MIR verification failed: full-program layout field changed during canonicalization",
                        ctx
                    );
                };
                field_types.Push(mir_native_full_program_type_identity(
                    field_type, env, ctx
                ));
                field_index = field_index + 1;
            }
            ctx.Set(value.field_names, field_names);
            ctx.Set(value.field_types, field_types);
            layouts.Push(value);
            layout_index = layout_index + 1;
        }
        ctx.Set(updated.layouts, layouts);

        mut enums: std.Vector[MirNativeFullProgramEnum[ctx], ctx] :=
            std.VectorNew(ctx);
        mut enum_names := typechecker.typechecker_get_sorted_keys_enum(
            &(*env).enum_registry, ctx
        );
        mut enum_index := 0;
        while enum_index < len(enum_names) {
            guard enum_variants := (*env).enum_registry.Get(
                enum_names[enum_index]
            ) else {
                return mir_native_full_program_invalid(
                    updated,
                    "Native backend canonical MIR verification failed: full-program enum registry changed during canonicalization",
                    ctx
                );
            };
            mut enumeration: MirNativeFullProgramEnum[ctx];
            enumeration.name = std.Clone(ctx, enum_names[enum_index]);
            enumeration.erased_name = codegen.codegen_get_erased_struct_name(
                enumeration.name, env, ctx
            );
            enumeration.variants = mir_native_full_program_empty_string_vector(ctx);
            mut variants: std.Vector[str, ctx] := std.VectorNew(ctx);
            mut variant_index := 0;
            while variant_index < len(enum_variants) {
                variants.Push(std.Clone(ctx, enum_variants[variant_index]));
                variant_index = variant_index + 1;
            }
            ctx.Set(enumeration.variants, variants);
            enums.Push(enumeration);
            enum_index = enum_index + 1;
        }
        ctx.Set(updated.enums, enums);
    }
    return updated;
}

func mir_native_full_program_analyze_signatures(programs: std.Vector[ast.Program[ctx], ctx], module_prefixes: std.Vector[str, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) MirNativeFullProgramModel[ctx] {
    mut model := mir_native_full_program_empty_model(ctx);
    if len(programs) == 0 || len(programs) != len(module_prefixes) {
        return model;
    }

    mut functions: std.Vector[MirNativeFullProgramFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut non_scalar_signature_count := 0;
    mut module_index := 0;
    while module_index < len(programs) {
        unsafe {
            (*env).current_prefix = module_prefixes[module_index];
        }
        mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[programs[module_index].statements];
        mut statement_index := 0;
        while statement_index < len(top_level) {
            mut statement := top_level[statement_index];
            unsafe {
                if statement.tag == 3 {
                    mut function: MirNativeFullProgramFunction[ctx];
                    function.module_index = module_index;
                    function.source_name = std.Clone(
                        ctx,
                        statement.FunctionDecl.name
                    );
                    function.qualified_name =
                        mir_native_full_program_qualified_name(
                            module_prefixes[module_index],
                            statement.FunctionDecl.name,
                            ctx
                        );
                    function.is_extern = statement.FunctionDecl.is_extern;
                    function.extern_symbol_name = std.Clone(
                        ctx,
                        statement.FunctionDecl.extern_symbol_name
                    );
                    if function.is_extern == 1 &&
                       len(function.extern_symbol_name) == 0
                    {
                        function.extern_symbol_name = std.Clone(
                            ctx,
                            statement.FunctionDecl.name
                        );
                    }
                    function.parameter_types =
                        mir_native_full_program_empty_string_vector(ctx);
                    function.parameter_names =
                        mir_native_full_program_empty_string_vector(ctx);
                    function.return_type = std.Clone(ctx, "");
                    function.body = statement.FunctionDecl.body;
                    function.body_node_index = 0 - 1;

                    if mir_native_full_program_function_index(
                        functions,
                        function.qualified_name,
                        ctx
                    ) >= 0 {
                        return mir_native_full_program_invalid(
                            model,
                            "Native backend canonical MIR verification failed: duplicate fully qualified full-program function symbol",
                            ctx
                        );
                    }

                    mut parameter_types: std.Vector[str, ctx] :=
                        std.VectorNew(ctx);
                    mut parameter_names: std.Vector[str, ctx] :=
                        std.VectorNew(ctx);
                    mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                        ctx[statement.FunctionDecl.params];
                    mut parameter_index := 0;
                    while parameter_index < len(parameters) {
                        mut identity :=
                            mir_native_full_program_type_identity(
                                parameters[parameter_index].param_type,
                                env,
                                ctx
                            );
                        if len(identity) == 0 ||
                           std.str_eq(identity, "Unknown") == 1
                        {
                            return mir_native_full_program_invalid(
                                model,
                                "Native backend canonical MIR verification failed: full-program parameter type has no resolved canonical identity",
                                ctx
                            );
                        }
                        if mir_native_full_program_type_is_initial_scalar(
                            parameters[parameter_index].param_type,
                            env,
                            ctx
                        ) == 0 {
                            non_scalar_signature_count =
                                non_scalar_signature_count + 1;
                        }
                        parameter_types.Push(identity);
                        parameter_names.Push(std.Clone(
                            ctx, parameters[parameter_index].name
                        ));
                        parameter_index = parameter_index + 1;
                    }
                    ctx.Set(function.parameter_types, parameter_types);
                    ctx.Set(function.parameter_names, parameter_names);

                    mut return_type :=
                        ctx[statement.FunctionDecl.return_type];
                    function.return_type =
                        mir_native_full_program_type_identity(
                            return_type,
                            env,
                            ctx
                        );
                    if len(function.return_type) == 0 ||
                       std.str_eq(function.return_type, "Unknown") == 1
                    {
                        return mir_native_full_program_invalid(
                            model,
                            "Native backend canonical MIR verification failed: full-program result type has no resolved canonical identity",
                            ctx
                        );
                    }
                    if mir_native_full_program_type_is_initial_scalar(
                        return_type,
                        env,
                        ctx
                    ) == 0 {
                        non_scalar_signature_count =
                            non_scalar_signature_count + 1;
                    }
                    functions.Push(function);
                }
            }
            statement_index = statement_index + 1;
        }
        module_index = module_index + 1;
    }
    if non_scalar_signature_count == 0 {
        unsafe { (*env).current_prefix = ""; }
        return model;
    }

    model.represented = 1;
    model.function_count = len(functions);
    model.non_scalar_signature_count = non_scalar_signature_count;

    // Second pass: lower every non-extern body only after the complete symbol
    // table exists. This permits recursive and cross-module calls without
    // making traversal order an ABI decision.
    module_index = 0;
    while module_index < len(programs) {
        unsafe { (*env).current_prefix = module_prefixes[module_index]; }
        mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[programs[module_index].statements];
        mut statement_index := 0;
        while statement_index < len(top_level) {
            mut statement := top_level[statement_index];
            unsafe {
                if statement.tag == 3 &&
                   statement.FunctionDecl.is_extern == 0 {
                    mut qualified_name :=
                        mir_native_full_program_qualified_name(
                            module_prefixes[module_index],
                            statement.FunctionDecl.name,
                            ctx
                        );
                    mut function_index :=
                        mir_native_full_program_function_index(
                            functions,
                            qualified_name,
                            ctx
                        );
                    if function_index < 0 {
                        return mir_native_full_program_invalid(
                            model,
                            "Native backend canonical MIR verification failed: full-program function disappeared before executable body lowering",
                            ctx
                        );
                    }
                    mut body_node := mir_native_full_program_flatten_block(
                        statement.FunctionDecl.body,
                        model.nodes,
                        env,
                        ctx
                    );
                    if body_node < 0 {
                        return mir_native_full_program_invalid(
                            model,
                            "Native backend canonical MIR verification failed: full-program executable body has an unresolved type or operation",
                            ctx
                        );
                    }
                    mut updated := functions[function_index];
                    updated.body_node_index = body_node;
                    functions.Set(function_index, updated);
                }
            }
            statement_index = statement_index + 1;
        }
        module_index = module_index + 1;
    }
    unsafe { (*env).current_prefix = ""; }
    ctx.Set(model.functions, functions);

    model = mir_native_full_program_collect_layout_authority(
        model, env, ctx
    );
    if model.invalid == 1 {
        return model;
    }

    mut entry_index :=
        mir_native_full_program_function_index(functions, "main", ctx);
    if entry_index < 0 {
        return mir_native_full_program_invalid(
            model,
            "Native backend canonical MIR verification failed: full-program bundle is missing main",
            ctx
        );
    }
    model.entry_function_index = entry_index;
    return model;
}

func mir_native_full_program_utf8_hex(value: str, ctx: &Arena) str {
    unsafe {
        mut digits := "0123456789abcdef";
        mut output_size := len(value) * 2;
        mut buffer := os.ScratchAlloc(output_size + 1);
        mut destination := buffer as *byte;
        mut index := 0;
        while index < len(value) {
            mut byte_value := std.str_byte_at(value, index);
            *(destination + index * 2) =
                std.str_byte_at(digits, byte_value / 16);
            *(destination + index * 2 + 1) = std.str_byte_at(
                digits,
                byte_value - (byte_value / 16) * 16
            );
            index = index + 1;
        }
        *(destination + output_size) = 0;

        mut header_alloc := os.ScratchAlloc(16);
        mut header_ptr :=
            (header_alloc + 0) as *MirNativeFullProgramStringHeader;
        if 0 == 1 {
            header_ptr = destination as *MirNativeFullProgramStringHeader;
        }
        (*header_ptr).data = (buffer + 0) as *byte;
        (*header_ptr).len = output_size;
        return *(((header_ptr as *str) + 0) as *str);
    }
}

func mir_native_full_program_append_int(value: str, integer: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(value, std.FormatInt(integer)));
}

func mir_native_full_program_integer_width(value: int) int {
    if value == 0 {
        return 1;
    }
    mut width := 0;
    mut remaining := value;
    if remaining < 0 {
        width = 1;
    }
    while remaining != 0 {
        width = width + 1;
        remaining = remaining / 10;
    }
    return width;
}

func mir_native_full_program_write_text(destination: *byte, cursor: int, value: str) int {
    unsafe {
        mut index := 0;
        while index < len(value) {
            *(destination + cursor) = std.str_byte_at(value, index);
            cursor = cursor + 1;
            index = index + 1;
        }
    }
    return cursor;
}

func mir_native_full_program_write_utf8_hex(destination: *byte, cursor: int, value: str) int {
    unsafe {
        mut digits := "0123456789abcdef";
        mut index := 0;
        while index < len(value) {
            mut byte_value := std.str_byte_at(value, index);
            *(destination + cursor) =
                std.str_byte_at(digits, byte_value / 16);
            *(destination + cursor + 1) = std.str_byte_at(
                digits,
                byte_value - (byte_value / 16) * 16
            );
            cursor = cursor + 2;
            index = index + 1;
        }
    }
    return cursor;
}

func mir_native_full_program_write_integer(destination: *byte, cursor: int, value: int) int {
    unsafe {
        mut width := mir_native_full_program_integer_width(value);
        mut end := cursor + width;
        mut write_index := end - 1;
        mut remaining := value;
        if remaining < 0 {
            *(destination + cursor) = 45;
        }
        if remaining == 0 {
            *(destination + write_index) = 48;
            return end;
        }
        while remaining != 0 {
            mut quotient := remaining / 10;
            mut digit := remaining - quotient * 10;
            if digit < 0 {
                digit = 0 - digit;
            }
            *(destination + write_index) = 48 + digit;
            write_index = write_index - 1;
            remaining = quotient;
        }
        return end;
    }
}

func mir_native_full_program_serialize_module_row(module_index: int, module_path: str, module_prefix: str, ctx: &Arena) str {
    mut row := "module: ";
    row = mir_native_full_program_append_int(row, module_index, ctx);
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        module_path, ctx
    ));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        module_prefix, ctx
    ));
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

func mir_native_full_program_serialize_function_row(function_index: int, function: MirNativeFullProgramFunction[ctx], ctx: &Arena) str {
    mut row := "function: ";
    row = mir_native_full_program_append_int(row, function_index, ctx);
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, function.module_index, ctx);
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        function.source_name, ctx
    ));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        function.qualified_name, ctx
    ));
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, function.is_extern, ctx);
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        function.extern_symbol_name, ctx
    ));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        function.return_type, ctx
    ));
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(
        row, function.body_node_index, ctx
    );
    mut parameter_types: std.Vector[str, ctx] :=
        ctx[function.parameter_types];
    mut parameter_names: std.Vector[str, ctx] :=
        ctx[function.parameter_names];
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, len(parameter_types), ctx);
    mut parameter_index := 0;
    while parameter_index < len(parameter_types) {
        row = std.Concat(row, "|");
        row = std.Concat(row, mir_native_full_program_utf8_hex(
            parameter_names[parameter_index], ctx
        ));
        row = std.Concat(row, "|");
        row = std.Concat(row, mir_native_full_program_utf8_hex(
            parameter_types[parameter_index], ctx
        ));
        parameter_index = parameter_index + 1;
    }
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

func mir_native_full_program_serialize_node_row(node_index: int, node: MirNativeFullProgramNode[ctx], ctx: &Arena) str {
    mut row := "node: ";
    row = mir_native_full_program_append_int(row, node_index, ctx);
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(node.kind, ctx));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        node.type_identity, ctx
    ));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        node.text_operand, ctx
    ));
    row = std.Concat(row, "|");
    row = std.Concat(row, mir_native_full_program_utf8_hex(
        node.second_text_operand, ctx
    ));
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, node.integer_operand, ctx);
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(
        row, node.second_integer_operand, ctx
    );
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, node.source_line, ctx);
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, node.source_column, ctx);
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(
        row, node.source_start_offset, ctx
    );
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(
        row, node.source_end_offset, ctx
    );
    mut children: std.Vector[int, ctx] := ctx[node.children];
    row = std.Concat(row, "|");
    row = mir_native_full_program_append_int(row, len(children), ctx);
    mut child_index := 0;
    while child_index < len(children) {
        row = std.Concat(row, "|");
        row = mir_native_full_program_append_int(
            row, children[child_index], ctx
        );
        child_index = child_index + 1;
    }
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

func mir_native_full_program_serialize_model(model: MirNativeFullProgramModel[ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) str {
    mut target_triple := os.NativeTargetTriple(ctx);
    mut object_format := os.NativeObjectFormat(ctx);
    mut functions: std.Vector[MirNativeFullProgramFunction[ctx], ctx] :=
        ctx[model.functions];
    mut nodes: std.Vector[MirNativeFullProgramNode[ctx], ctx] :=
        ctx[model.nodes];
    mut layouts: std.Vector[MirNativeFullProgramLayout[ctx], ctx] :=
        ctx[model.layouts];
    mut enums: std.Vector[MirNativeFullProgramEnum[ctx], ctx] :=
        ctx[model.enums];

    // Size the complete canonical transport first, then fill one exact buffer.
    // The compiler arena is non-reclaiming, so incremental Concat here would
    // retain every prefix of a full-compiler bundle and exceed the registered
    // Patch 21 memory budget despite a small final transport.
    mut total_size := len("format: gust.compiler_executable_mir.v1\n");
    total_size = total_size + len("target_triple_utf8_hex: ") +
        len(target_triple) * 2 + 1;
    total_size = total_size + len("object_format_utf8_hex: ") +
        len(object_format) * 2 + 1;
    total_size = total_size + len("module_count: ") +
        mir_native_full_program_integer_width(len(module_paths)) + 1;
    mut module_index := 0;
    while module_index < len(module_paths) {
        total_size = total_size + len("module: ") +
            mir_native_full_program_integer_width(module_index) + 1 +
            len(module_paths[module_index]) * 2 + 1 +
            len(module_prefixes[module_index]) * 2 + 1;
        module_index = module_index + 1;
    }
    total_size = total_size + len("layout_count: ") +
        mir_native_full_program_integer_width(len(layouts)) + 1;
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut layout := layouts[layout_index];
        mut field_names: std.Vector[str, ctx] := ctx[layout.field_names];
        mut field_types: std.Vector[str, ctx] := ctx[layout.field_types];
        total_size = total_size + len("layout: ") +
            mir_native_full_program_integer_width(layout_index) + 1 +
            len(layout.name) * 2 + 1 + len(layout.erased_name) * 2 + 1 +
            len(layout.brand) * 2 + 1 +
            mir_native_full_program_integer_width(layout.is_repr_c) + 1 +
            mir_native_full_program_integer_width(layout.is_packed) + 1 +
            len(layout.layout_abi) * 2 + 1 +
            mir_native_full_program_integer_width(len(field_names)) + 1;
        mut field_index := 0;
        while field_index < len(field_names) {
            total_size = total_size + 1 + len(field_names[field_index]) * 2 +
                1 + len(field_types[field_index]) * 2;
            field_index = field_index + 1;
        }
        layout_index = layout_index + 1;
    }
    total_size = total_size + len("enum_count: ") +
        mir_native_full_program_integer_width(len(enums)) + 1;
    mut enum_index := 0;
    while enum_index < len(enums) {
        mut enumeration := enums[enum_index];
        mut variants: std.Vector[str, ctx] := ctx[enumeration.variants];
        total_size = total_size + len("enum: ") +
            mir_native_full_program_integer_width(enum_index) + 1 +
            len(enumeration.name) * 2 + 1 +
            len(enumeration.erased_name) * 2 + 1 +
            mir_native_full_program_integer_width(len(variants)) + 1;
        mut variant_index := 0;
        while variant_index < len(variants) {
            total_size = total_size + 1 + len(variants[variant_index]) * 2;
            variant_index = variant_index + 1;
        }
        enum_index = enum_index + 1;
    }
    total_size = total_size + len("function_count: ") +
        mir_native_full_program_integer_width(len(functions)) + 1;
    mut function_index := 0;
    while function_index < len(functions) {
        mut function := functions[function_index];
        mut parameter_types: std.Vector[str, ctx] :=
            ctx[function.parameter_types];
        mut parameter_names: std.Vector[str, ctx] :=
            ctx[function.parameter_names];
        total_size = total_size + len("function: ") +
            mir_native_full_program_integer_width(function_index) + 1 +
            mir_native_full_program_integer_width(function.module_index) + 1 +
            len(function.source_name) * 2 + 1 +
            len(function.qualified_name) * 2 + 1 +
            mir_native_full_program_integer_width(function.is_extern) + 1 +
            len(function.extern_symbol_name) * 2 + 1 +
            len(function.return_type) * 2 + 1 +
            mir_native_full_program_integer_width(function.body_node_index) + 1 +
            mir_native_full_program_integer_width(len(parameter_types)) + 1;
        mut parameter_index := 0;
        while parameter_index < len(parameter_types) {
            total_size = total_size + 1 +
                len(parameter_names[parameter_index]) * 2 + 1 +
                len(parameter_types[parameter_index]) * 2;
            parameter_index = parameter_index + 1;
        }
        function_index = function_index + 1;
    }
    total_size = total_size + len("node_count: ") +
        mir_native_full_program_integer_width(len(nodes)) + 1;
    mut node_index := 0;
    while node_index < len(nodes) {
        mut node := nodes[node_index];
        mut children: std.Vector[int, ctx] := ctx[node.children];
        total_size = total_size + len("node: ") +
            mir_native_full_program_integer_width(node_index) + 1 +
            len(node.kind) * 2 + 1 +
            len(node.type_identity) * 2 + 1 +
            len(node.text_operand) * 2 + 1 +
            len(node.second_text_operand) * 2 + 1 +
            mir_native_full_program_integer_width(node.integer_operand) + 1 +
            mir_native_full_program_integer_width(node.second_integer_operand) + 1 +
            mir_native_full_program_integer_width(node.source_line) + 1 +
            mir_native_full_program_integer_width(node.source_column) + 1 +
            mir_native_full_program_integer_width(node.source_start_offset) + 1 +
            mir_native_full_program_integer_width(node.source_end_offset) + 1 +
            mir_native_full_program_integer_width(len(children)) + 1;
        mut child_index := 0;
        while child_index < len(children) {
            total_size = total_size + 1 +
                mir_native_full_program_integer_width(children[child_index]);
            child_index = child_index + 1;
        }
        node_index = node_index + 1;
    }
    total_size = total_size + len("entry_function_index: ") +
        mir_native_full_program_integer_width(model.entry_function_index) + 1;

    unsafe {
        mut buffer := os.ScratchAlloc(total_size + 1);
        mut destination := buffer as *byte;
        mut cursor := 0;
        cursor = mir_native_full_program_write_text(
            destination, cursor,
            "format: gust.compiler_executable_mir.v1\n"
        );
        cursor = mir_native_full_program_write_text(
            destination, cursor, "target_triple_utf8_hex: "
        );
        cursor = mir_native_full_program_write_utf8_hex(
            destination, cursor, target_triple
        );
        cursor = mir_native_full_program_write_text(
            destination, cursor, "\nobject_format_utf8_hex: "
        );
        cursor = mir_native_full_program_write_utf8_hex(
            destination, cursor, object_format
        );
        cursor = mir_native_full_program_write_text(
            destination, cursor, "\nmodule_count: "
        );
        cursor = mir_native_full_program_write_integer(
            destination, cursor, len(module_paths)
        );
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        module_index = 0;
        while module_index < len(module_paths) {
            cursor = mir_native_full_program_write_text(
                destination, cursor, "module: "
            );
            cursor = mir_native_full_program_write_integer(
                destination, cursor, module_index
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, module_paths[module_index]
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, module_prefixes[module_index]
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "\n");
            module_index = module_index + 1;
        }
        cursor = mir_native_full_program_write_text(
            destination, cursor, "layout_count: "
        );
        cursor = mir_native_full_program_write_integer(
            destination, cursor, len(layouts)
        );
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        layout_index = 0;
        while layout_index < len(layouts) {
            mut layout := layouts[layout_index];
            mut field_names: std.Vector[str, ctx] := ctx[layout.field_names];
            mut field_types: std.Vector[str, ctx] := ctx[layout.field_types];
            cursor = mir_native_full_program_write_text(destination, cursor, "layout: ");
            cursor = mir_native_full_program_write_integer(destination, cursor, layout_index);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, layout.name);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, layout.erased_name);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, layout.brand);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, layout.is_repr_c);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, layout.is_packed);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, layout.layout_abi);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, len(field_names));
            mut field_index := 0;
            while field_index < len(field_names) {
                cursor = mir_native_full_program_write_text(destination, cursor, "|");
                cursor = mir_native_full_program_write_utf8_hex(destination, cursor, field_names[field_index]);
                cursor = mir_native_full_program_write_text(destination, cursor, "|");
                cursor = mir_native_full_program_write_utf8_hex(destination, cursor, field_types[field_index]);
                field_index = field_index + 1;
            }
            cursor = mir_native_full_program_write_text(destination, cursor, "\n");
            layout_index = layout_index + 1;
        }
        cursor = mir_native_full_program_write_text(destination, cursor, "enum_count: ");
        cursor = mir_native_full_program_write_integer(destination, cursor, len(enums));
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        enum_index = 0;
        while enum_index < len(enums) {
            mut enumeration := enums[enum_index];
            mut variants: std.Vector[str, ctx] := ctx[enumeration.variants];
            cursor = mir_native_full_program_write_text(destination, cursor, "enum: ");
            cursor = mir_native_full_program_write_integer(destination, cursor, enum_index);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, enumeration.name);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, enumeration.erased_name);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, len(variants));
            mut variant_index := 0;
            while variant_index < len(variants) {
                cursor = mir_native_full_program_write_text(destination, cursor, "|");
                cursor = mir_native_full_program_write_utf8_hex(destination, cursor, variants[variant_index]);
                variant_index = variant_index + 1;
            }
            cursor = mir_native_full_program_write_text(destination, cursor, "\n");
            enum_index = enum_index + 1;
        }
        cursor = mir_native_full_program_write_text(
            destination, cursor, "function_count: "
        );
        cursor = mir_native_full_program_write_integer(
            destination, cursor, len(functions)
        );
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        function_index = 0;
        while function_index < len(functions) {
            mut function := functions[function_index];
            mut parameter_types: std.Vector[str, ctx] :=
                ctx[function.parameter_types];
            mut parameter_names: std.Vector[str, ctx] :=
                ctx[function.parameter_names];
            cursor = mir_native_full_program_write_text(
                destination, cursor, "function: "
            );
            cursor = mir_native_full_program_write_integer(
                destination, cursor, function_index
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(
                destination, cursor, function.module_index
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, function.source_name
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, function.qualified_name
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(
                destination, cursor, function.is_extern
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, function.extern_symbol_name
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(
                destination, cursor, function.return_type
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(
                destination, cursor, function.body_node_index
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(
                destination, cursor, len(parameter_types)
            );
            mut parameter_index := 0;
            while parameter_index < len(parameter_types) {
                cursor = mir_native_full_program_write_text(
                    destination, cursor, "|"
                );
                cursor = mir_native_full_program_write_utf8_hex(
                    destination, cursor, parameter_names[parameter_index]
                );
                cursor = mir_native_full_program_write_text(
                    destination, cursor, "|"
                );
                cursor = mir_native_full_program_write_utf8_hex(
                    destination, cursor, parameter_types[parameter_index]
                );
                parameter_index = parameter_index + 1;
            }
            cursor = mir_native_full_program_write_text(destination, cursor, "\n");
            function_index = function_index + 1;
        }
        cursor = mir_native_full_program_write_text(
            destination, cursor, "node_count: "
        );
        cursor = mir_native_full_program_write_integer(
            destination, cursor, len(nodes)
        );
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        node_index = 0;
        while node_index < len(nodes) {
            mut node := nodes[node_index];
            mut children: std.Vector[int, ctx] := ctx[node.children];
            cursor = mir_native_full_program_write_text(
                destination, cursor, "node: "
            );
            cursor = mir_native_full_program_write_integer(
                destination, cursor, node_index
            );
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, node.kind);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, node.type_identity);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, node.text_operand);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_utf8_hex(destination, cursor, node.second_text_operand);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.integer_operand);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.second_integer_operand);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.source_line);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.source_column);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.source_start_offset);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, node.source_end_offset);
            cursor = mir_native_full_program_write_text(destination, cursor, "|");
            cursor = mir_native_full_program_write_integer(destination, cursor, len(children));
            mut child_index := 0;
            while child_index < len(children) {
                cursor = mir_native_full_program_write_text(destination, cursor, "|");
                cursor = mir_native_full_program_write_integer(
                    destination, cursor, children[child_index]
                );
                child_index = child_index + 1;
            }
            cursor = mir_native_full_program_write_text(destination, cursor, "\n");
            node_index = node_index + 1;
        }
        cursor = mir_native_full_program_write_text(
            destination, cursor, "entry_function_index: "
        );
        cursor = mir_native_full_program_write_integer(
            destination, cursor, model.entry_function_index
        );
        cursor = mir_native_full_program_write_text(destination, cursor, "\n");
        if cursor != total_size {
            return std.Clone(ctx, "");
        }
        *(destination + cursor) = 0;
        mut header_alloc := os.ScratchAlloc(16);
        mut header_ptr :=
            (header_alloc + 0) as *MirNativeFullProgramStringHeader;
        if 0 == 1 {
            header_ptr = destination as *MirNativeFullProgramStringHeader;
        }
        (*header_ptr).data = (buffer + 0) as *byte;
        (*header_ptr).len = total_size;
        return *(((header_ptr as *str) + 0) as *str);
    }
}

func mir_native_full_program_emit_bundle(model: MirNativeFullProgramModel[ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut canonical := mir_native_full_program_serialize_model(
        model, module_paths, module_prefixes, ctx
    );
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        module_paths[len(module_paths) - 1],
        "",
        "phase21_full_compiler.o",
        "gust.compiler_executable_mir.v1",
        canonical,
        0,
        0,
        0,
        ctx
    );
    // The strict full-program payload already owns every definition, import,
    // signature, and linkage. Repeating its 1,800+ symbol index in the outer
    // legacy bundle is redundant and makes the self-hosted concatenating
    // serializer quadratic. The outer bundle owns only publication of `main`;
    // the worker re-derives and validates the complete symbol table from the
    // canonical payload before object emission.
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol(
            "main",
            "main",
            std.Concat(
                "full_program_signature:",
                std.FormatInt(model.entry_function_index)
            ),
            0,
            ctx
        ),
        ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_full_program_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) MirNativeFullProgramSourceResult[ctx] {
    mut result: MirNativeFullProgramSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);

    if len(module_paths) != len(programs) {
        return result;
    }
    mut model := mir_native_full_program_analyze_signatures(
        programs,
        module_prefixes,
        env,
        ctx
    );
    result.represented = model.represented;
    if model.invalid == 1 {
        result.invalid = 1;
        result.diagnostic = std.Clone(ctx, model.diagnostic);
        return result;
    }
    if model.represented == 0 {
        return result;
    }

    result.bundle = mir_native_full_program_emit_bundle(
        model, module_paths, module_prefixes, ctx
    );
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    return result;
}
