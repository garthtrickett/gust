import "ast.gst" as ast;
import "token.gst" as token;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;
import "mir_function_abi_authority.gst" as function_abi;
import "mir_function_call.gst" as call_mir;

type Codegen[ctx] struct {
    env: &typechecker.TypeEnvironment[ctx],
    current_alloc_struct: str,
    current_params: std.Vector[str, ctx]
}


type CodegenStringHeader struct {
    data: *byte,
    len: int
}

func codegen_join_chunks(chunks: std.Vector[str, ctx], ctx: &Arena) str {
    unsafe {
        mut total_size := 0;
        mut chunk_index := 0;
        while chunk_index < len(chunks) {
            total_size = total_size + len(chunks[chunk_index]);
            chunk_index = chunk_index + 1;
        }
        if total_size == 0 {
            return std.Clone(ctx, "");
        }

        mut buffer := os.ScratchAlloc(total_size + 1);
        mut destination := buffer as *byte;
        mut write_index := 0;
        chunk_index = 0;
        while chunk_index < len(chunks) {
            mut chunk := chunks[chunk_index];
            mut byte_index := 0;
            while byte_index < len(chunk) {
                *(destination + write_index) = std.str_byte_at(chunk, byte_index);
                write_index = write_index + 1;
                byte_index = byte_index + 1;
            }
            chunk_index = chunk_index + 1;
        }
        *(destination + write_index) = 0;

        mut header_alloc := os.ScratchAlloc(16);
        mut header_ptr := (header_alloc + 0) as *CodegenStringHeader;
        if 0 == 1 {
            header_ptr = destination as *CodegenStringHeader;
        }
        (*header_ptr).data = (buffer + 0) as *byte;
        (*header_ptr).len = write_index;
        return *(((header_ptr as *str) + 0) as *str);
    }
}

func codegen_get_c_type_name_by_struct_name(name: str, ctx: &Arena) str {
    if std.str_eq(name, "str") == 1 {
        return "Slice_unsigned_char";
    } else {
        if std.str_eq(name, "int") == 1 {
            return "int";
        } else {
            if std.str_eq(name, "byte") == 1 || std.str_eq(name, "bool") == 1 {
                return "unsigned char";
            } else {
                if std.str_eq(name, "Arena") == 1 || std.str_eq(name, "os_Arena") == 1 || std.str_eq(name, "os.Arena") == 1 {
                    return "os_Arena";
                }
            }
        }
    }
    return std.Clone(ctx, name);
}

func codegen_escape_string(val: str, ctx: &Arena) str {
    mut res := "";
    mut i := 0;
    while i < len(val) {
        mut b := std.str_byte_at(val, i);
        if b == 92 {
            res = std.Concat(res, "\\\\");
        } else {
            if b == 34 {
                res = std.Concat(res, "\\\"");
            } else {
                if b == 10 {
                    res = std.Concat(res, "\\n");
                } else {
                    if b == 9 {
                        res = std.Concat(res, "\\t");
                    } else {
                        if b == 13 {
                            res = std.Concat(res, "\\r");
                        } else {
                            mut char_slice := std.str_slice(val, i, i + 1);
                            res = std.Concat(res, char_slice);
                        }
                    }
                }
            }
        }
        i = i + 1;
    }
    return std.Clone(ctx, res);
}

func init_codegen(c: *Codegen[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) {
    unsafe {
        (*c).env = env;
        (*c).current_alloc_struct = "";
        (*c).current_params = std.VectorNew(ctx);
    }
}

func codegen_expr_calls_func(expr_idx: Index[ast.Expression[ctx], ctx], func_name: str, ctx: &Arena) int { 
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return 0;
        }
        mut expr := ctx[expr_idx];
        mut tag := expr.tag;
        
        if tag == 0 { // Identifier
            return 0;
        }
        if tag == 1 { // Integer
            return 0;
        }
        if tag == 2 { // String
            return 0;
        }
        if tag == 3 { // Bool
            return 0;
        }
        if tag == 4 { // Move
            return codegen_expr_calls_func(expr.Move.expr, func_name, ctx);
        }
        if tag == 5 { // Take
            return codegen_expr_calls_func(expr.Take.expr, func_name, ctx);
        }
        if tag == 6 { // AddressOf
            return codegen_expr_calls_func(expr.AddressOf.expr, func_name, ctx);
        }
        if tag == 7 { // Dereference
            return codegen_expr_calls_func(expr.Dereference.expr, func_name, ctx);
        }
        if tag == 8 { // IndexAccess
            if codegen_expr_calls_func(expr.IndexAccess.allocator, func_name, ctx) == 1 { return 1; }
            if codegen_expr_calls_func(expr.IndexAccess.index, func_name, ctx) == 1 { return 1; }
            return 0;
        }
        if tag == 9 { // AsCast
            return codegen_expr_calls_func(expr.AsCast.left, func_name, ctx);
        }
        if tag == 10 { // Binary
            if codegen_expr_calls_func(expr.Binary.left, func_name, ctx) == 1 { return 1; }
            if codegen_expr_calls_func(expr.Binary.right, func_name, ctx) == 1 { return 1; }
            return 0;
        }
        if tag == 11 { // Selector
            return codegen_expr_calls_func(expr.Selector.left, func_name, ctx);
        }
        if tag == 12 { // Call
            mut call_func_expr_idx := expr.Call.function;
            mut called_name := "";
            if call_func_expr_idx != empty[Index[ast.Expression[ctx], ctx]] {
                mut call_func := ctx[call_func_expr_idx];
                if call_func.tag == 0 { // Identifier
                    called_name = call_func.Identifier.name;
                } else {
                    if call_func.tag == 11 { // Selector
                        mut left_expr := call_func.Selector.left;
                        if left_expr != empty[Index[ast.Expression[ctx], ctx]] {
                            mut left := ctx[left_expr];
                            if left.tag == 0 { // Identifier
                                called_name = std.Concat(std.Concat(left.Identifier.name, "."), call_func.Selector.right);
                            }
                        }
                    }
                }
            }

            mut is_match := 0;
            if std.str_eq(called_name, func_name) == 1 {
                is_match = 1;
            } else {
                mut dot_suffix := std.Concat(".", func_name);
                if codegen_ends_with(called_name, dot_suffix) == 1 {
                    is_match = 1;
                }
            }

            if is_match == 1 {
                return 1;
            }

            mut args_vec_expr_calls_func: std.Vector[ast.Expression[ctx], ctx] := ctx[expr.Call.arguments];
            mut i := 0;
            while i < len(args_vec_expr_calls_func) {
                mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg_idx, args_vec_expr_calls_func[i]);
                if codegen_expr_calls_func(arg_idx, func_name, ctx) == 1 {
                    return 1;
                }
                i = i + 1;
            }
            return 0;
        }
        if tag == 13 { // Empty
            return 0;
        }
        if tag == 14 { // Query (Phase 21.3 semantic no-op)
            return codegen_expr_calls_func(expr.Query.terminal, func_name, ctx);
        }
    }
    return 0;
}

func codegen_block_calls_func(block_idx: Index[ast.BlockStatement[ctx], ctx], func_name: str, ctx: &Arena) int {
    unsafe {
        if block_idx == empty[Index[ast.BlockStatement[ctx], ctx]] {
            return 0;
        }
        mut block_val_calls_func := ctx[block_idx];
        mut body_statements_block_calls_func: std.Vector[ast.Statement[ctx], ctx] := ctx[block_val_calls_func.statements];
        mut j := 0;
        while j < len(body_statements_block_calls_func) {
            mut child_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx.Set(child_stmt_idx, body_statements_block_calls_func[j]);
            if codegen_stmt_calls_func(child_stmt_idx, func_name, ctx) == 1 {
                return 1;
            }
            j = j + 1;
        } 
    }
    return 0;
}

func codegen_stmt_calls_func(stmt_idx: Index[ast.Statement[ctx], ctx], func_name: str, ctx: &Arena) int {
    unsafe {
        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return 0;
        }
        mut stmt := ctx[stmt_idx];
        mut tag := stmt.tag;

        if tag == 0 { // Import
            return 0;
        }
        if tag == 1 { // StructDecl
            return 0;
        }
        if tag == 2 { // EnumDecl
            return 0;
        }
        if tag == 3 { // FunctionDecl
            return 0;
        }
        if tag == 4 { // VarDecl
            return codegen_expr_calls_func(stmt.VarDecl.value, func_name, ctx);
        }
        if tag == 5 { // Assignment
            if codegen_expr_calls_func(stmt.Assignment.left, func_name, ctx) == 1 { return 1; }
            if codegen_expr_calls_func(stmt.Assignment.value, func_name, ctx) == 1 { return 1; }
            return 0;
        }
        if tag == 6 { // While
            if codegen_expr_calls_func(stmt.While.condition, func_name, ctx) == 1 { return 1; }
            return codegen_block_calls_func(stmt.While.body, func_name, ctx);
        }
        if tag == 7 { // If
            if codegen_expr_calls_func(stmt.If.condition, func_name, ctx) == 1 { return 1; }
            if codegen_block_calls_func(stmt.If.consequence, func_name, ctx) == 1 { return 1; }
            if codegen_block_calls_func(stmt.If.alternative, func_name, ctx) == 1 { return 1; }
            return 0;
        }
        if tag == 8 { // Match
            if codegen_expr_calls_func(stmt.Match.expression, func_name, ctx) == 1 { return 1; }
            mut cases_vec_stmt_calls_func: std.Vector[ast.MatchCase[ctx], ctx] := ctx[stmt.Match.cases];
            mut i := 0;
            while i < len(cases_vec_stmt_calls_func) {
                mut case_val := cases_vec_stmt_calls_func[i];
                if codegen_block_calls_func(case_val.body, func_name, ctx) == 1 {
                    return 1;
                }
                i = i + 1;
            }
            return 0;
        }
        if tag == 9 { // Guard
            if codegen_expr_calls_func(stmt.Guard.value, func_name, ctx) == 1 { return 1; }
            return codegen_block_calls_func(stmt.Guard.else_body, func_name, ctx);
        }
        if tag == 10 { // UnsafeBlock
            return codegen_block_calls_func(stmt.UnsafeBlock.body, func_name, ctx);
        }
        if tag == 11 { // Defer
            return codegen_expr_calls_func(stmt.Defer.expr, func_name, ctx);
        }
        if tag == 12 { // Return
            return codegen_expr_calls_func(stmt.Return.expr, func_name, ctx);
        }
        if tag == 13 { // Expression
            return codegen_expr_calls_func(stmt.Expression.expr, func_name, ctx);
        }
    }
    return 0;
}

func codegen_is_function_recursive(body_idx: Index[ast.BlockStatement[ctx], ctx], func_name: str, ctx: &Arena) int {
    return codegen_block_calls_func(body_idx, func_name, ctx);
}

func codegen_ends_with(s: str, suffix: str) int {
    mut len_s := len(s);
    mut len_suffix := len(suffix);
    if len_s < len_suffix {
        return 0;
    }
    mut sliced := std.str_slice(s, len_s - len_suffix, len_s);
    if std.str_eq(sliced, suffix) == 1 {
        return 1;
    }
    return 0;
}

func codegen_is_slice_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    return typechecker.typechecker_classify_type(t, typechecker.typechecker_classification_slice(), env, ctx);
}

func codegen_is_ptr_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    return typechecker.typechecker_classify_type(t, typechecker.typechecker_classification_pointer(), env, ctx);
}

func codegen_is_vector_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int { 
    return typechecker.typechecker_classify_type(t, typechecker.typechecker_classification_vector(), env, ctx);
}

func codegen_is_pool_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    return typechecker.typechecker_classify_type(t, typechecker.typechecker_classification_pool(), env, ctx);
}

func codegen_is_hashmap_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    return typechecker.typechecker_classify_type(t, typechecker.typechecker_classification_hashmap(), env, ctx);
}

func codegen_is_rc_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut curr := t;
        while curr.tag == 9 || curr.tag == 11 { // RawPointer or Reference
            if curr.tag == 9 {
                curr = ctx[curr.RawPointer.inner];
            } else {
                curr = ctx[curr.Reference.inner];
            }
        }
        if curr.tag == 8 { // Struct
            mut name := curr.Struct.struct_name;
            mut erased_name := codegen_get_erased_struct_name(name, env, ctx);
            if std.str_find(erased_name, "Rc_") == 0 || std.str_find(erased_name, "std_Rc_") == 0 { 
                return 1;
            }
        }
        if curr.tag == 10 { // Generic
            mut name := curr.Generic.name;
            if std.str_eq(name, "Rc") == 1 || std.str_eq(name, "std.Rc") == 1 || std.str_eq(name, "std_Rc") == 1 { 
                return 1;
            }
        }
    }
    return 0;
}

func codegen_is_graph_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut curr := t;
        while curr.tag == 9 || curr.tag == 11 { // RawPointer or Reference
            if curr.tag == 9 {
                curr = ctx[curr.RawPointer.inner];
            } else {
                curr = ctx[curr.Reference.inner];
            }
        }
        if curr.tag == 8 { // Struct
            mut name := curr.Struct.struct_name;
            mut erased_name := codegen_get_erased_struct_name(name, env, ctx);
            if std.str_find(erased_name, "Graph_") == 0 || std.str_find(erased_name, "std_Graph_") == 0 { 
                return 1;
            }
        }
        if curr.tag == 10 { // Generic
            mut name := curr.Generic.name;
            if std.str_eq(name, "Graph") == 1 || std.str_eq(name, "std.Graph") == 1 || std.str_eq(name, "std_Graph") == 1 { 
                return 1;
            }
        }
    }
    return 0;
}

func codegen_is_generational_arena_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut curr := t;
        while curr.tag == 9 || curr.tag == 11 { // RawPointer or Reference
            if curr.tag == 9 {
                curr = ctx[curr.RawPointer.inner];
            } else {
                curr = ctx[curr.Reference.inner];
            }
        }
        if curr.tag == 8 { // Struct
            mut name := curr.Struct.struct_name;
            mut erased_name := codegen_get_erased_struct_name(name, env, ctx);
            if std.str_find(erased_name, "GenerationalArena_") == 0 || std.str_find(erased_name, "std_GenerationalArena_") == 0 { 
                return 1;
            }
        }
        if curr.tag == 10 { // Generic
            mut name := curr.Generic.name;
            if std.str_eq(name, "GenerationalArena") == 1 || std.str_eq(name, "std.GenerationalArena") == 1 || std.str_eq(name, "std_GenerationalArena") == 1 { 
                return 1;
            }
        }
    }
    return 0;
}

func codegen_hashmap_is_str_key(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        if codegen_is_hashmap_type(t, env, ctx) == 0 {
            return 0;
        }
        if t.tag == 8 { // Struct
            mut name := t.Struct.struct_name;
            mut erased_name := codegen_get_erased_struct_name(name, env, ctx);
            mut orig_name := codegen_find_original_struct_name(erased_name, env, ctx);
            mut lookup_struct := (*env).struct_registry.get_opt(orig_name);
            match lookup_struct {
                Some { val } => {
                    mut layout := *val;
                    mut keys_type_lookup := layout.fields.get_opt("keys");
                    match keys_type_lookup {
                        Some { val } => {
                            mut keys_type := *val;
                            if keys_type.tag == 9 { // RawPointer
                                mut key_elem_type := ctx[keys_type.RawPointer.inner];
                                if key_elem_type.tag == 5 { // Str
                                    return 1;
                                }
                            }
                        }
                        None => {
                        }
                    }
                }
                None => {
                }
            }
        }
        if t.tag == 10 { // Generic
            mut args_vec_type_contains_str_raw: std.Vector[ast.Type[ctx], ctx] := ctx[t.Generic.args];
            if len(args_vec_type_contains_str_raw) > 0 {
                mut first_arg := args_vec_type_contains_str_raw[0];
                if first_arg.tag == 5 { // Str
                    return 1;
                }
            }
        }
    }
    return 0;
}

func codegen_rfind_char(s: str, ch: int, end_idx: int) int {
    mut j := end_idx - 1;
    while j >= 0 {
        if std.str_byte_at(s, j) == ch {
            return j;
        }
        j = j - 1;
    }
    return 0 - 1;
}

func codegen_erase_struct_name(name: str, brand: Index[str, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    mut canonical_name := typechecker.env_get_canonical_branded_type_name(env, name, brand, ctx);
    if std.str_eq(canonical_name, "") == 0 {
        return std.Clone(ctx, canonical_name);
    }
    mut resolved_name := typechecker.env_resolve_namespaced_ident(env, name, ctx);
    return std.Clone(ctx, resolved_name);
}

func codegen_is_brand_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    return typechecker.typechecker_type_is_brand_marker(t, ctx);
}


func codegen_erase_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) ast.Type[ctx] {
    unsafe {
        mut erased_t := t;
        if t.tag == 8 {
            mut name := t.Struct.struct_name;
            mut brand := t.Struct.brand;
            mut erased_name := codegen_erase_struct_name(name, brand, env, ctx);
            erased_t.Struct.struct_name = erased_name;
            erased_t.Struct.brand = empty[Index[str, ctx]];
            return erased_t;
        }
        if t.tag == 7 {
            mut name := t.Index.struct_name;
            mut brand := t.Index.brand;
            mut erased_name := codegen_erase_struct_name(name, brand, env, ctx);
            erased_t.Index.struct_name = erased_name;
            erased_t.Index.brand = empty[Index[str, ctx]];
            return erased_t;
        }
        if t.tag == 9 {
            mut inner := ctx[t.RawPointer.inner];
            mut erased_inner := codegen_erase_type(inner, env, ctx);
            erased_t.RawPointer.inner = os.ArenaAlloc(ctx);
            ctx.Set(erased_t.RawPointer.inner, erased_inner);
            return erased_t;
        }
        if t.tag == 6 {
            mut inner := ctx[t.Slice.inner];
            mut erased_inner := codegen_erase_type(inner, env, ctx);
            erased_t.Slice.inner = os.ArenaAlloc(ctx);
            ctx.Set(erased_t.Slice.inner, erased_inner);
            return erased_t;
        }
        if t.tag == 11 { // Reference
            mut inner := ctx[t.Reference.inner];
            mut erased_inner := codegen_erase_type(inner, env, ctx);
            erased_t.Reference.inner = os.ArenaAlloc(ctx);
            ctx.Set(erased_t.Reference.inner, erased_inner);
            erased_t.Reference.brand = empty[Index[str, ctx]];
            return erased_t;
        }
        if t.tag == 10 {
            mut name := t.Generic.name;
            mut args_vec_erase_type_generic: std.Vector[ast.Type[ctx], ctx] := ctx[t.Generic.args];
            mut erased_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            mut brand_parameter_index := typechecker.env_get_template_brand_parameter_index(env, name);

            mut i := 0;
            while i < len(args_vec_erase_type_generic) {
                mut arg := args_vec_erase_type_generic[i];
                if i != brand_parameter_index && codegen_is_brand_type(arg, env, ctx) == 0 {
                    mut erased_arg := codegen_erase_type(arg, env, ctx);
                    erased_args.Push(erased_arg);
                }
                i = i + 1;
            }
            erased_t.Generic.args = os.ArenaAlloc(ctx);
            ctx.Set(erased_t.Generic.args, erased_args);
            return erased_t;
        }
        return t;
    }
}

func codegen_get_erased_struct_name(name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut lookup := (*env).struct_registry.get_opt(name);
        match lookup {
            Some { val } => {
                mut b := (*val).brand;
                return std.Clone(ctx, codegen_erase_struct_name(name, b, env, ctx));
            }
            None => {
            }
        }
        return std.Clone(ctx, codegen_erase_struct_name(name, empty[Index[str, ctx]], env, ctx));
    }
}

func codegen_find_original_struct_name(erased_name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut keys := typechecker.typechecker_get_sorted_keys_layout(&(*env).struct_registry, ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            mut current_erased := codegen_get_erased_struct_name(key, env, ctx);
            if std.str_eq(current_erased, erased_name) == 1 {
                return std.Clone(ctx, key);
            }
            i = i + 1;
        }
    }
    return std.Clone(ctx, erased_name);
}


func codegen_expression_is_arena_ptr(expr_idx: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    mut t := typechecker.env_resolve_type(env, codegen_get_expression_type(expr_idx, env, ctx), ctx);
    mut is_arena := typechecker.typechecker_classify_resolved_type(t, typechecker.typechecker_classification_arena(), env, ctx);
    if is_arena == 1 && (t.tag == 9 || t.tag == 11) { // RawPointer or Reference
        return 1;
    }
    return 0;
}

func codegen_argument_value_class(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    mut resolved := typechecker.env_resolve_type(env, t, ctx);
    if typechecker.typechecker_classify_resolved_type(resolved, typechecker.typechecker_classification_arena(), env, ctx) == 1 { return "arena"; }
    if typechecker.typechecker_classify_resolved_type(resolved, typechecker.typechecker_classification_vector(), env, ctx) == 1 { return "vector"; }
    if typechecker.typechecker_classify_resolved_type(resolved, typechecker.typechecker_classification_hashmap(), env, ctx) == 1 { return "hashmap"; }
    if typechecker.typechecker_classify_resolved_type(resolved, typechecker.typechecker_classification_pool(), env, ctx) == 1 { return "pool"; }
    return "value";
}

func codegen_plan_argument_representation_for_value_class(t: ast.Type[ctx], value_class: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) call_mir.MirArgumentRepresentation[ctx] {
    mut resolved := typechecker.env_resolve_type(env, t, ctx);
    mut pointer_like := 0;
    if t.tag == 9 || t.tag == 11 || resolved.tag == 9 || resolved.tag == 11 { pointer_like = 1; } // RawPointer or Reference
    mut passing_mode := function_abi.mir_abi_parameter_passing_mode_for_value_class(value_class, pointer_like);
    return call_mir.mir_call_argument_representation(passing_mode, ctx);
}

func codegen_plan_argument_representation_for_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) call_mir.MirArgumentRepresentation[ctx] {
    mut resolved := typechecker.env_resolve_type(env, t, ctx);
    return codegen_plan_argument_representation_for_value_class(t, codegen_argument_value_class(resolved, env, ctx), env, ctx);
}

func codegen_plan_argument_representation(expr_idx: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) call_mir.MirArgumentRepresentation[ctx] {
    return codegen_plan_argument_representation_for_type(codegen_get_expression_type(expr_idx, env, ctx), env, ctx);
}

func codegen_emit_argument_representation(expression: str, representation: call_mir.MirArgumentRepresentation[ctx], ctx: &Arena) str {
    if std.str_eq(representation.materialization, "by_value") == 1 {
        return std.Clone(ctx, expression);
    }
    if std.str_eq(representation.materialization, "by_address") == 1 {
        mut output := std.Concat("&(", expression);
        output = std.Concat(output, ")");
        return std.Clone(ctx, output);
    }
    os.LogStr("Fatal Error: canonical MIR argument representation is invalid");
    os.Exit(1);
    return "";
}

func codegen_plan_brand_argument_representation(brand_name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) call_mir.MirArgumentRepresentation[ctx] {
    unsafe {
        mut i := 0;
        while i < len((*env).current_params) {
            if std.str_eq((*env).current_params[i], brand_name) == 1 {
                return call_mir.mir_call_argument_representation("direct", ctx);
            }
            i = i + 1;
        }
        mut lookup := (*env).variable_types.Get(brand_name);
        if lookup.Ok {
            mut resolved := typechecker.env_resolve_type(env, lookup.Val, ctx);
            if resolved.tag == 9 || resolved.tag == 11 { // RawPointer or Reference
                return call_mir.mir_call_argument_representation("direct", ctx);
            }
        }
    }
    return call_mir.mir_call_argument_representation("indirect_by_reference", ctx);
}

func codegen_should_skip_fwd_decl(name: str) int {
    if std.str_eq(name, "std.Clone") { return 1; }
    if std.str_eq(name, "std_Clone") { return 1; }
    if std.str_eq(name, "std.RcNew") { return 1; }
    if std.str_eq(name, "std_RcNew") { return 1; }
    if std.str_eq(name, "std.GenerationalSwap") { return 1; }
    if std.str_eq(name, "std_GenerationalSwap") { return 1; }
    if std.str_eq(name, "std.PoolNew") { return 1; }
    if std.str_eq(name, "std_PoolNew") { return 1; }
    if std.str_eq(name, "os.PoolNew") { return 1; }
    if std.str_eq(name, "os_PoolNew") { return 1; }
    if std.str_eq(name, "std.VectorNew") { return 1; }
    if std.str_eq(name, "std_VectorNew") { return 1; }
    if std.str_eq(name, "os.VectorNew") { return 1; }
    if std.str_eq(name, "os_VectorNew") { return 1; }
    if std.str_eq(name, "std.VectorGetRef") { return 1; }
    if std.str_eq(name, "std_VectorGetRef") { return 1; }
    if std.str_eq(name, "std.HashMapNew") { return 1; }
    if std.str_eq(name, "std_HashMapNew") { return 1; }
    if std.str_eq(name, "os.HashMapNew") { return 1; }
    if std.str_eq(name, "os_HashMapNew") { return 1; }
    if std.str_eq(name, "std.GraphNew") { return 1; }
    if std.str_eq(name, "std_GraphNew") { return 1; }
    if std.str_eq(name, "os_GraphNew") { return 1; }
    if std.str_eq(name, "os.GraphNew") { return 1; }
    if std.str_eq(name, "os.ArenaAlloc") { return 1; }
    if std.str_eq(name, "os_ArenaAlloc") { return 1; }
    if std.str_eq(name, "os.ArenaValidate") { return 1; }
    if std.str_eq(name, "os_ArenaValidate") { return 1; }
    if std.str_eq(name, "os.ScratchAlloc") { return 1; }
    if std.str_eq(name, "os_ScratchAlloc") { return 1; }
    if std.str_eq(name, "os.ScratchReset") { return 1; }
    if std.str_eq(name, "os_ScratchReset") { return 1; }
    if std.str_eq(name, "std.FormatInt") { return 1; }
    if std.str_eq(name, "std_FormatInt") { return 1; }
    if std.str_eq(name, "std.Concat") { return 1; }
    if std.str_eq(name, "std_Concat") { return 1; }
    if std.str_eq(name, "std.MutexNew") { return 1; }
    if std.str_eq(name, "std_MutexNew") { return 1; }
    if std.str_eq(name, "std.ChannelNew") { return 1; }
    if std.str_eq(name, "std_ChannelNew") { return 1; }
    if std.str_eq(name, "os.Args") { return 1; }
    if std.str_eq(name, "os_Args") { return 1; }
    if std.str_eq(name, "os.Exit") { return 1; }
    if std.str_eq(name, "os_Exit") { return 1; }
    if std.str_eq(name, "os.ReadFile") { return 1; }
    if std.str_eq(name, "os_ReadFile") { return 1; }
    if std.str_eq(name, "os.WriteFile") { return 1; }
    if std.str_eq(name, "os_WriteFile") { return 1; }
    if std.str_eq(name, "os.LogError") { return 1; }
    if std.str_eq(name, "os_LogError") { return 1; }
    if std.str_eq(name, "os.GetEnv") { return 1; }
    if std.str_eq(name, "os_GetEnv") { return 1; }
    if std.str_eq(name, "os.ExecutablePath") { return 1; }
    if std.str_eq(name, "os_ExecutablePath") { return 1; }
    if std.str_eq(name, "os.PathAbsolute") { return 1; }
    if std.str_eq(name, "os_PathAbsolute") { return 1; }
    if std.str_eq(name, "os.PathDir") { return 1; }
    if std.str_eq(name, "os_PathDir") { return 1; }
    if std.str_eq(name, "os.NativeTargetTriple") { return 1; }
    if std.str_eq(name, "os_NativeTargetTriple") { return 1; }
    if std.str_eq(name, "os.NativeObjectFormat") { return 1; }
    if std.str_eq(name, "os_NativeObjectFormat") { return 1; }
    if std.str_eq(name, "os.FileExists") { return 1; }
    if std.str_eq(name, "os_FileExists") { return 1; }
    if std.str_eq(name, "os.FileExecutable") { return 1; }
    if std.str_eq(name, "os_FileExecutable") { return 1; }
    if std.str_eq(name, "os.RemoveFile") { return 1; }
    if std.str_eq(name, "os_RemoveFile") { return 1; }
    if std.str_eq(name, "os.RunProcess") { return 1; }
    if std.str_eq(name, "os_RunProcess") { return 1; }
    if std.str_eq(name, "os.path_join") { return 1; }
    if std.str_eq(name, "os_path_join") { return 1; }
    if std.str_eq(name, "os.LogInt") { return 1; }
    if std.str_eq(name, "os_LogInt") { return 1; }
    if std.str_eq(name, "os.LogStr") { return 1; }
    if std.str_eq(name, "os_LogStr") { return 1; }
    if std.str_eq(name, "os.MockPayload") { return 1; }
    if std.str_eq(name, "os_MockPayload") { return 1; }
    if std.str_eq(name, "std.str_eq") { return 1; }
    if std.str_eq(name, "std_str_eq") { return 1; }
    if std.str_eq(name, "std.str_slice") { return 1; }
    if std.str_eq(name, "std_str_slice") { return 1; }
    if std.str_eq(name, "std.str_byte_at") { return 1; }
    if std.str_eq(name, "std_str_byte_at") { return 1; }
    if std.str_eq(name, "std.str_find") { return 1; }
    if std.str_eq(name, "std_str_find") { return 1; }
    if std.str_eq(name, "std.str_trim") { return 1; }
    if std.str_eq(name, "std_str_trim") { return 1; }
    if std.str_eq(name, "std.str_split") { return 1; }
    if std.str_eq(name, "std_str_split") { return 1; }
    if std.str_eq(name, "std.Spawn") { return 1; }
    if std.str_eq(name, "std_Spawn") { return 1; }
    if std.str_eq(name, "std.is_alpha") { return 1; }
    if std.str_eq(name, "std_is_alpha") { return 1; }
    if std.str_eq(name, "std.is_digit") { return 1; }
    if std.str_eq(name, "std_is_digit") { return 1; }
    if std.str_eq(name, "std.is_whitespace") { return 1; }
    if std.str_eq(name, "std_is_whitespace") { return 1; }
    if std.str_eq(name, "std.parse_int") { return 1; }
    if std.str_eq(name, "std_parse_int") { return 1; }
    if std.str_eq(name, "os.GetThreadScratch") { return 1; }
    if std.str_eq(name, "os_GetThreadScratch") { return 1; }
    if std.str_eq(name, "std.Format") { return 1; }
    if std.str_eq(name, "std_Format") { return 1; }
    if std.str_eq(name, "os.OpenDir") { return 1; }
    if std.str_eq(name, "os_OpenDir") { return 1; }
    if std.str_eq(name, "os.ReadDir") { return 1; }
    if std.str_eq(name, "os_ReadDir") { return 1; }
    if std.str_eq(name, "os.CloseDir") { return 1; }
    if std.str_eq(name, "os_CloseDir") { return 1; }
    return 0;
}

func codegen_gen_function_fwd_decl(name: str, sig: typechecker.FunctionSignature[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut ret_c_type := codegen_get_c_type(sig.return_type, env, ctx);
        
        mut c_func_name := "";
        if sig.is_extern == 1 && len(sig.extern_symbol_name) > 0 {
            c_func_name = std.Clone(ctx, sig.extern_symbol_name);
        } else {
            mut char_idx := 0;
            while char_idx < len(name) {
                mut b := std.str_byte_at(name, char_idx);
                if b == 46 { // '.'
                    c_func_name = std.Concat(c_func_name, "_");
                } else {
                    c_func_name = std.Concat(c_func_name, std.str_slice(name, char_idx, char_idx + 1));
                }
                char_idx = char_idx + 1;
            }
        }

        mut params_str := "";
        mut i := 0;
        while i < len(sig.params) {
            if i > 0 {
                params_str = std.Concat(params_str, ", ");
            }
            mut param_type := sig.params[i];
            mut p_name := sig.param_names[i];

            mut is_arena_ptr := 0;
            if param_type.tag == 9 { // RawPointer
                mut inner_idx := param_type.RawPointer.inner as Index[ast.Type[ctx], ctx];
                mut inner := ctx[inner_idx];
                if inner.tag == 4 { // Arena
                    is_arena_ptr = 1;
                }
            }

            mut p_c_type := "";
            if is_arena_ptr == 1 || param_type.tag == 4 { // Arena or RawPointer(Arena)
                p_c_type = "os_Arena*";
            } else {
                p_c_type = codegen_get_c_type(param_type, env, ctx);
            }

            mut p_decl := std.Concat(p_c_type, " ");
            p_decl = std.Concat(p_decl, p_name);
            params_str = std.Concat(params_str, p_decl);
            i = i + 1;
        }

            if len(sig.params) == 0 {
                params_str = "void";
            }

        mut res := std.Concat(ret_c_type, " ");
        res = std.Concat(res, c_func_name);
        res = std.Concat(res, "(");
        res = std.Concat(res, params_str);
        res = std.Concat(res, ");\n");
        return std.Clone(ctx, res);
    }
}

func codegen_get_by_value_dependencies_recursive(t: ast.Type[ctx], deps: *std.HashMap[str, int, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) {
    unsafe {
        if t.tag == 8 { // Struct
            mut name := t.Struct.struct_name;
            mut lookup_struct := (*env).struct_registry.get_opt(name);
            match lookup_struct {
                Some { val } => {
                    mut inserted := 0;
                    mut has_dep := 0;
                    mut dep_lookup := (*deps).get_opt(name);
                    match dep_lookup {
                        Some { val } => {
                            has_dep = 1;
                        }
                        None => {
                        }
                    }
                    if has_dep == 0 {
                        (*deps).Insert(std.Clone(ctx, name), 1);
                        inserted = 1;
                    }
                    if inserted == 1 {
                        mut layout := *val;
                        mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                        mut j := 0;
                        while j < len(f_keys) {
                            mut f_key := f_keys[j];
                            mut f_lookup := layout.fields.get_opt(f_key);
                            match f_lookup {
                                Some { val } => {
                                    codegen_get_by_value_dependencies_recursive(*val, deps, env, ctx);
                                }
                                None => {
                                }
                            }
                            j = j + 1;
                        }
                    }
                }
                None => {
                }
            }
        } else {
            if t.tag == 6 { // Slice
                mut inner := ctx[t.Slice.inner];
                codegen_get_by_value_dependencies_recursive(inner, deps, env, ctx);
            } else {
                if t.tag == 10 { // Generic
                    mut args_vec_by_value_deps: std.Vector[ast.Type[ctx], ctx] := ctx[t.Generic.args];
                    mut i := 0;
                    while i < len(args_vec_by_value_deps) {
                        codegen_get_by_value_dependencies_recursive(args_vec_by_value_deps[i], deps, env, ctx);
                        i = i + 1;
                    }
                }
            }
        }
    }
}

func codegen_topological_visit(name: str, visited: *std.HashMap[str, int, ctx], temp_visited: *std.HashMap[str, int, ctx], ordered: *std.Vector[str, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut has_visited := 0;
        mut visited_lookup := (*visited).get_opt(name);
        match visited_lookup {
            Some { val } => {
                has_visited = 1;
            }
            None => {
            }
        }
        if has_visited == 1 {
            return 1;
        }
        
        mut has_temp_visited := 0;
        mut temp_visited_lookup := (*temp_visited).get_opt(name);
        match temp_visited_lookup {
            Some { val } => {
                has_temp_visited = 1;
            }
            None => {
            }
        }
        if has_temp_visited == 1 {
            return 0;
        }
        (*temp_visited).Insert(std.Clone(ctx, name), 1);

        mut lookup_struct := (*env).struct_registry.get_opt(name);
        match lookup_struct {
            Some { val } => {
                mut layout := *val;
                mut deps_map: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
                
                mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                mut j := 0;
                while j < len(f_keys) {
                    mut f_key := f_keys[j];
                    mut f_lookup := layout.fields.get_opt(f_key);
                    match f_lookup {
                        Some { val } => {
                            codegen_get_by_value_dependencies_recursive(*val, &deps_map, env, ctx);
                        }
                        None => {
                        }
                    }
                    j = j + 1;
                }

                mut lookup_enum := env.enum_registry.Get(name);
                if lookup_enum.Ok {
                    mut variants := lookup_enum.Val;
                    mut v_idx := 0;
                    while v_idx < len(variants) {
                        mut variant_name := variants[v_idx];
                        mut variant_struct_name := std.Concat(name, "_");
                        variant_struct_name = std.Concat(variant_struct_name, variant_name);
                        deps_map.Insert(std.Clone(ctx, variant_struct_name), 1);
                        v_idx = v_idx + 1;
                    }
                }

                mut sorted_deps := typechecker.typechecker_get_sorted_keys_int(&deps_map, ctx);
                mut d_idx := 0;
                while d_idx < len(sorted_deps) {
                    mut dep := sorted_deps[d_idx];
                    mut ok := codegen_topological_visit(dep, visited, temp_visited, ordered, env, ctx);
                    if ok == 0 {
                        return 0;
                    }
                    d_idx = d_idx + 1;
                }
            }
            None => {
            }
        }

        (*temp_visited).Remove(name);
        (*visited).Insert(std.Clone(ctx, name), 1);
        (*ordered).Push(std.Clone(ctx, name));
        return 1;
    }
}

func codegen_get_topologically_sorted_structs(env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) std.Vector[str, ctx] { 
    unsafe {
        mut ordered: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut visited: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
        mut temp_visited: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);

        mut all_structs := typechecker.typechecker_get_sorted_keys_layout(&(*env).struct_registry, ctx);
        mut i := 0;
        while i < len(all_structs) {
            mut name := all_structs[i];
            mut ok := codegen_topological_visit(name, &visited, &temp_visited, &ordered, env, ctx);
            if ok == 0 {
                os.LogStr("Fatal Error: Value-embedding cycle detected during topological sort");
                os.Exit(1);
            }
            i = i + 1;
        }
        return ordered;
    }
}

func codegen_log_trace(emoji: str, message: str, ctx: &Arena) {
}

func codegen_get_expression_span(expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) token.Span {
    mut s: token.Span;
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] { 
            return s;
        }
        mut expr := ctx[expr_idx];
        if expr.tag == 0 { s = expr.Identifier.span; }
        if expr.tag == 1 { s = expr.Integer.span; }
        if expr.tag == 2 { s = expr.String.span; }
        if expr.tag == 3 { s = expr.Bool.span; }
        if expr.tag == 4 { s = expr.Move.span; }
        if expr.tag == 5 { s = expr.Take.span; }
        if expr.tag == 6 { s = expr.AddressOf.span; }
        if expr.tag == 7 { s = expr.Dereference.span; }
        if expr.tag == 8 { s = expr.IndexAccess.span; }
        if expr.tag == 9 { s = expr.AsCast.span; }
        if expr.tag == 10 { s = expr.Binary.span; }
        if expr.tag == 11 { s = expr.Selector.span; }
        if expr.tag == 12 { s = expr.Call.span; }
        if expr.tag == 13 { s = expr.Empty.span; }
        if expr.tag == 14 { s = expr.Query.span; }
    } 
    return s;
}

func codegen_get_expression_type(expr_idx: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) ast.Type[ctx] { 
    unsafe {
        mut dummy: ast.Type[ctx];
        dummy.tag = 3; // Void
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return dummy;
        }
        mut span := codegen_get_expression_span(expr_idx, ctx);
        mut prefix := typechecker.typechecker_resolution_scope_key(env as *typechecker.TypeEnvironment[ctx], ctx);
        
        mut found_idx := 0 - 1;
        mut i := 0;
        while i < len((*env).resolved_types_nested) {
            mut entry := (*env).resolved_types_nested[i];
            if std.str_eq(entry.prefix, prefix) {
                found_idx = i;
                i = len((*env).resolved_types_nested);
            }
            i = i + 1;
        }
        
        if found_idx != 0 - 1 {
            mut entry_ref := &(*env).resolved_types_nested[found_idx];
            mut j := 0;
            while j < len((*entry_ref).types) {
                mut t_entry := (*entry_ref).types[j];
                if t_entry.start_offset == span.start.offset && t_entry.end_offset == span.end.offset {
                    return t_entry.val_type;
                }
                j = j + 1;
            }
        }
        return dummy;

    }
}

func codegen_contextual_constructor_struct_name(expr_idx: Index[ast.Expression[ctx], ctx], fallback: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut selected := fallback;
        if std.str_eq((*env).current_alloc_struct, "") == 0 {
            selected = (*env).current_alloc_struct;
        }

        mut expression_type := codegen_get_expression_type(expr_idx, env, ctx);
        expression_type = typechecker.env_resolve_type(env, expression_type, ctx);
        if expression_type.tag == 8 { // Struct
            mut recorded := codegen_get_erased_struct_name(
                expression_type.Struct.struct_name, env, ctx
            );
            if codegen_ends_with(recorded, "_Any") == 0 {
                selected = recorded;
            }
        }
        return std.Clone(ctx, selected);
    }
}

func codegen_get_c_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str { 
    unsafe {
        mut resolved_t := typechecker.env_resolve_type(env, t, ctx);
        mut erased_t := codegen_erase_type(resolved_t, env, ctx);
        if codegen_is_brand_type(erased_t, env, ctx) == 1 {
            return "void";
        }
        if erased_t.tag == 0 { // Int
            return "int";
        }
        if erased_t.tag == 1 { // Byte
            return "unsigned char";
        }
        if erased_t.tag == 2 { // Bool
            return "unsigned char";
        }
        if erased_t.tag == 3 { // Void
            return "void";
        }
        if erased_t.tag == 4 { // Arena
            return "os_Arena";
        }
        if erased_t.tag == 5 { // Str
            return "Slice_unsigned_char";
        }
        if erased_t.tag == 6 { // Slice
            mut inner_type := ctx[erased_t.Slice.inner];
            mut inner_ident := codegen_get_c_type_ident(inner_type, env, ctx);
            mut res := std.Concat("Slice_", inner_ident);
            return std.Clone(ctx, res);
        }
        if erased_t.tag == 7 { // Index
            return "int";
        }
        if erased_t.tag == 8 { // Struct
            mut name := erased_t.Struct.struct_name;
            if std.str_eq(name, "str") == 1 {
                return "Slice_unsigned_char";
            }
            return std.Clone(ctx, name);
        }
        if erased_t.tag == 9 { // RawPointer
            mut inner_type := ctx[erased_t.RawPointer.inner];
            mut inner_c := codegen_get_c_type(inner_type, env, ctx);
            mut res := std.Concat(inner_c, "*");
            return std.Clone(ctx, res);
        }
        if erased_t.tag == 11 { // Reference
            mut inner_type := ctx[erased_t.Reference.inner];
            mut inner_c := codegen_get_c_type(inner_type, env, ctx);
            mut res := std.Concat(inner_c, "*");
            return std.Clone(ctx, res);
        }
        if erased_t.tag == 10 { // Generic
            mut mono_name := codegen_get_monomorphized_name(erased_t.Generic.name, erased_t.Generic.args, env, ctx);
            return std.Clone(ctx, mono_name);
        }
    }
    return "unknown";
}


func codegen_get_c_type_ident(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str { 
    mut c_type := codegen_get_c_type(t, env, ctx);
    mut out := "";
    mut i := 0;
    while i < len(c_type) {
        mut b := std.str_byte_at(c_type, i);
        if b == 42 { // '*'
            out = std.Concat(out, "_ptr");
        } else {
            if b == 32 { // ' '
                out = std.Concat(out, "_");
            } else {
                mut char_slice := std.str_slice(c_type, i, i + 1);
                out = std.Concat(out, char_slice);
            }
        }
        i = i + 1;
    }
    return std.Clone(ctx, out);
}

func codegen_get_monomorphized_name(template_name: str, args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut args_vec_monomorphized_name: std.Vector[ast.Type[ctx], ctx] := ctx[args_idx];
        mut arg_names := "";
        mut i := 0;
        while i < len(args_vec_monomorphized_name) {
            if i > 0 {
                arg_names = std.Concat(arg_names, "_");
            }
            mut erased_arg := codegen_erase_type(args_vec_monomorphized_name[i], env, ctx);
            mut arg_name := typechecker.get_type_ident(erased_arg, ctx);
            arg_names = std.Concat(arg_names, arg_name);
            i = i + 1;
        }
        mut name := std.Concat(template_name, "_");
        name = std.Concat(name, arg_names);

        mut out := "";
        mut j := 0;
        while j < len(name) {
            mut b := std.str_byte_at(name, j);
            if b == 46 { // '.' = 46
                out = std.Concat(out, "_");
            } else {
                mut char_slice := std.str_slice(name, j, j + 1);
                out = std.Concat(out, char_slice);
            }
            j = j + 1;
        }
        return std.Clone(ctx, out);
    }
}

func codegen_gen_struct_initializer(name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str { 
    unsafe {
        mut erased_name := codegen_get_erased_struct_name(name, env, ctx);
        mut orig_name := codegen_find_original_struct_name(erased_name, env, ctx);
        mut lookup_enum := env.enum_registry.Get(orig_name);
        if lookup_enum.Ok {
            mut res := std.Concat("((", erased_name);
            res = std.Concat(res, "){ .tag = 0 })");
            return std.Clone(ctx, res);
        }
        
        mut lookup_struct := (*env).struct_registry.get_opt(orig_name);
        match lookup_struct {
            Some { val } => {
                mut layout := *val;
                mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                if len(f_keys) == 0 {
                    mut res := std.Concat("((", erased_name);
                    res = std.Concat(res, "){0})");
                    return std.Clone(ctx, res);
                }
                
                mut fields_init := "";
                mut i := 0;
                while i < len(f_keys) {
                    mut f_key := f_keys[i];
                    mut f_lookup := layout.fields.get_opt(f_key);
                    match f_lookup {
                        Some { val } => {
                            if i > 0 {
                                fields_init = std.Concat(fields_init, ", ");
                            }
                            mut f_init := codegen_gen_type_aware_initializer(*val, env, ctx);
                            mut field_assign := std.Concat(".", f_key);
                            field_assign = std.Concat(field_assign, " = ");
                            field_assign = std.Concat(field_assign, f_init);
                            fields_init = std.Concat(fields_init, field_assign);
                        }
                        None => {
                        }
                    }
                    i = i + 1;
                }
                
                mut res := std.Concat("((", erased_name);
                res = std.Concat(res, "){ ");
                res = std.Concat(res, fields_init);
                res = std.Concat(res, " })");
                return std.Clone(ctx, res);
            }
            None => {
            }
        }
        
        mut res := std.Concat("((", erased_name);
        res = std.Concat(res, "){0})");
        return std.Clone(ctx, res);
    }
}

func codegen_has_boolean_fields_recursive(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], visited: *std.HashMap[str, int, ctx], ctx: &Arena) int {
    unsafe {
        if t.tag == 1 || t.tag == 2 { // Byte, Bool
            return 1;
        }
        if t.tag == 6 { // Slice
            mut inner_type := ctx[t.Slice.inner];
            return codegen_has_boolean_fields_recursive(inner_type, env, visited, ctx);
        }
        if t.tag == 9 { // RawPointer
            mut inner_type := ctx[t.RawPointer.inner];
            return codegen_has_boolean_fields_recursive(inner_type, env, visited, ctx);
        }
        if t.tag == 8 { // Struct
            mut name := t.Struct.struct_name;
            mut lookup := (*visited).get_opt(name);
            match lookup {
                Some { val } => {
                    return 0;
                }
                None => {
                }
            }
            (*visited).Insert(std.Clone(ctx, name), 1);
            
            mut lookup_struct := (*env).struct_registry.get_opt(name);
            match lookup_struct {
                Some { val } => {
                    mut layout := *val;
                    mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                    mut i := 0;
                    while i < len(f_keys) {
                        mut f_key := f_keys[i];
                        mut f_lookup := layout.fields.get_opt(f_key);
                        match f_lookup {
                            Some { val } => {
                                mut has_bool := codegen_has_boolean_fields_recursive(*val, env, visited, ctx);
                                if has_bool == 1 {
                                    return 1;
                                }
                            }
                            None => {
                            }
                        }
                        i = i + 1;
                    }
                }
                None => {
                }
            }
            return 0;
        }
        if t.tag == 10 { // Generic
            mut concrete_name := codegen_get_monomorphized_name(t.Generic.name, t.Generic.args, env, ctx);
            mut struct_type: ast.Type[ctx];
            struct_type.tag = 8;
            struct_type.Struct.struct_name = concrete_name;
            struct_type.Struct.brand = empty[Index[str, ctx]];
            return codegen_has_boolean_fields_recursive(struct_type, env, visited, ctx);
        }
    }
    return 0;
}

func codegen_has_boolean_fields(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut visited: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
        return codegen_has_boolean_fields_recursive(t, env, &visited, ctx);
    }
}

func codegen_gen_is_valid_helper(struct_name: str, layout: typechecker.StructLayout[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        codegen_log_trace("👁️", std.Format("codegen_gen_is_valid_helper: generating Invariant Validator for %s", struct_name), ctx);
        mut res := std.Concat("int ", struct_name);
        res = std.Concat(res, "_IsValid(");
        res = std.Concat(res, struct_name);
        res = std.Concat(res, "* req) {\n");
        res = std.Concat(res, "    if (req == NULL) return 0;\n");
        
        mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
        mut i := 0;
        while i < len(f_keys) {
            mut f_key := f_keys[i];
            mut f_lookup := layout.fields.get_opt(f_key);
            match f_lookup {
                Some { val } => {
                    mut f_type := *val;
                    if f_type.tag == 1 || f_type.tag == 2 { // Byte or Bool
                        mut check_line := std.Concat("    if (req->", f_key);
                        check_line = std.Concat(check_line, " != 0x00 && req->");
                        check_line = std.Concat(check_line, f_key);
                        check_line = std.Concat(check_line, " != 0x01) return 0;\n");
                        res = std.Concat(res, check_line);
                    } else {
                        if f_type.tag == 8 { // Struct
                            mut has_bool := codegen_has_boolean_fields(f_type, env, ctx);
                            if has_bool == 1 {
                                mut nested_name := f_type.Struct.struct_name;
                                mut check_line := std.Concat("    if (!", nested_name);
                                check_line = std.Concat(check_line, "_IsValid(&req->");
                                check_line = std.Concat(check_line, f_key);
                                check_line = std.Concat(check_line, ")) return 0;\n");
                                res = std.Concat(res, check_line);
                            }
                        }
                    }
                }
                None => {
                }
            }
            i = i + 1;
        }
        res = std.Concat(res, "    return 1;\n");
        res = std.Concat(res, "}\n");
        return std.Clone(ctx, res);
    }
}

func codegen_gen_type_aware_initializer(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut erased_t := codegen_erase_type(t, env, ctx);
        if erased_t.tag == 0 || erased_t.tag == 1 || erased_t.tag == 2 { // Int, Byte, Bool
            return "0";
        }
        if erased_t.tag == 3 { // Void
            return "";
        }
        if erased_t.tag == 4 { // Arena
            return "((os_Arena){0})";
        }
        if erased_t.tag == 5 { // Str
            return "((Slice_unsigned_char){ NULL, 0 })";
        }
        if erased_t.tag == 6 { // Slice
            mut inner_type := ctx[erased_t.Slice.inner];
            mut inner_ident := codegen_get_c_type_ident(inner_type, env, ctx);
            mut res := std.Concat("((Slice_", inner_ident);
            res = std.Concat(res, "){ NULL, 0 })");
            return std.Clone(ctx, res);
        }
        if erased_t.tag == 7 { // Index
            return "0xFFFFFFFF";
        }
        if erased_t.tag == 9 { // RawPointer
            return "NULL";
        }
        if erased_t.tag == 8 { // Struct
            return std.Clone(ctx, codegen_gen_struct_initializer(erased_t.Struct.struct_name, env, ctx));
        }
        if erased_t.tag == 10 { // Generic
            mut concrete_name := codegen_get_monomorphized_name(erased_t.Generic.name, erased_t.Generic.args, env, ctx);
            return std.Clone(ctx, codegen_gen_struct_initializer(concrete_name, env, ctx));
        }
    }
    return "0";
}

func codegen_strip_pointer_suffix(s: str, ctx: &Arena) str {
    mut end_idx := len(s);
    while end_idx > 0 {
        mut b := std.str_byte_at(s, end_idx - 1);
        if b == 42 || b == 32 { // '*' or ' '
            end_idx = end_idx - 1;
        } else {
            return std.Clone(ctx, std.str_slice(s, 0, end_idx));
        }
    }
    return s;
}

func codegen_generate_expression(expr_idx: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut tag := ctx[expr_idx].tag;
        if tag == 0 { // Identifier
            mut name := ctx[expr_idx].Identifier.name;
            if std.str_eq(name, "null") {
                return "0xFFFFFFFF";
            }
            return std.Clone(ctx, name);
        }
        if tag == 1 { // Integer
            return std.Clone(ctx, std.FormatInt(ctx[expr_idx].Integer.val));
        }
        if tag == 2 { // String
            mut val := ctx[expr_idx].String.val;
            mut escaped := codegen_escape_string(val, ctx);
            mut res := std.Concat("\"", escaped);
            res = std.Concat(res, "\"");
            mut len_str := std.FormatInt(len(val));
            mut sl := std.Concat("((Slice_unsigned_char){ (unsigned char*)", res);
            sl = std.Concat(sl, ", ");
            sl = std.Concat(sl, len_str);
            sl = std.Concat(sl, " })");
            return std.Clone(ctx, sl);
        }
        if tag == 3 { // Bool
            if ctx[expr_idx].Bool.val == 1 {
                return "1";
            }
            return "0";
        }
        if tag == 4 { // Move
            mut expr_str := codegen_generate_expression(ctx[expr_idx].Move.expr, env, ctx);
            
            mut is_lin := 0;
            mut inner_t := codegen_get_expression_type(ctx[expr_idx].Move.expr, env, ctx);
            if inner_t.tag != 3 { // Void - check if linear
                is_lin = typechecker.env_type_is_linear(inner_t, env, ctx);
            }
            
            mut can_memset := 0;
            if is_lin == 1 {
                mut inner_tag := ctx[ctx[expr_idx].Move.expr].tag;
                if inner_tag == 0 || inner_tag == 11 || inner_tag == 8 || inner_tag == 7 {
                    // Identifier = 0, Selector = 11, IndexAccess = 8, Dereference = 7
                    can_memset = 1;
                }
            }
            
            if can_memset == 1 {
                mut res := std.Concat("(({ __typeof__(", expr_str);
                res = std.Concat(res, ") _tmp = ");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, "; memset(&");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, ", 0, sizeof(");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, ")); _tmp; }))");
                return std.Clone(ctx, res);
            }
            return expr_str;
        }
        if tag == 5 { // Take
            mut expr_str := codegen_generate_expression(ctx[expr_idx].Take.expr, env, ctx);
            
            mut is_lin := 0;
            mut inner_t := codegen_get_expression_type(ctx[expr_idx].Take.expr, env, ctx);
            if inner_t.tag != 3 { // Void - check if linear
                is_lin = typechecker.env_type_is_linear(inner_t, env, ctx);
            }
            
            mut can_memset := 0;
            if is_lin == 1 {
                mut inner_tag := ctx[ctx[expr_idx].Take.expr].tag;
                if inner_tag == 0 || inner_tag == 11 || inner_tag == 8 || inner_tag == 7 {
                    // Identifier = 0, Selector = 11, IndexAccess = 8, Dereference = 7
                    can_memset = 1;
                }
            }
            
            if can_memset == 1 {
                mut res := std.Concat("(({ __typeof__(", expr_str);
                res = std.Concat(res, ") _tmp = ");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, "; memset(&");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, ", 0, sizeof(");
                res = std.Concat(res, expr_str);
                res = std.Concat(res, ")); _tmp; }))");
                return std.Clone(ctx, res);
            }
            return expr_str;
        }
        if tag == 6 { // AddressOf
            mut inner_idx := ctx[expr_idx].AddressOf.expr;
            mut is_cast_val := 0;
            if ctx[inner_idx].tag == 11 { // Selector
                mut inner_left := ctx[inner_idx].Selector.left;
                mut inner_left_type := codegen_get_expression_type(inner_left, env, ctx);
                if inner_left_type.tag == 8 { // Struct
                    mut struct_name := inner_left_type.Struct.struct_name;
                    mut clean_name := struct_name;
                    mut d_idx := std.str_find(struct_name, "__");
                    if d_idx != 0 - 1 {
                        clean_name = std.str_slice(struct_name, d_idx + 2, len(struct_name));
                    }
                    if len(clean_name) >= 11 && std.str_eq(std.str_slice(clean_name, 0, 11), "CastResult_") == 1 {
                        if std.str_eq(ctx[inner_idx].Selector.right, "Val") == 1 {
                            is_cast_val = 1;
                        }
                    }
                }
            }

            mut inner_str := codegen_generate_expression(inner_idx, env, ctx);
            if is_cast_val == 1 {
                return std.Clone(ctx, inner_str);
            }
            mut res := std.Concat("&(", inner_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if tag == 7 { // Dereference
            mut res := std.Concat("(*(", codegen_generate_expression(ctx[expr_idx].Dereference.expr, env, ctx));
            res = std.Concat(res, "))");
            return std.Clone(ctx, res);
        }

        if tag == 8 { // IndexAccess
            mut alloc_idx := ctx[expr_idx].IndexAccess.allocator;
            mut index_idx := ctx[expr_idx].IndexAccess.index;

            mut alloc_t := codegen_get_expression_type(alloc_idx, env, ctx);
            mut idx_t := codegen_get_expression_type(index_idx, env, ctx);

            mut resolved_alloc_t := typechecker.env_resolve_type(env, alloc_t, ctx);
            mut is_arena := typechecker.typechecker_classify_resolved_type(resolved_alloc_t, typechecker.typechecker_classification_arena(), env, ctx);

            mut alloc_str := codegen_generate_expression(alloc_idx, env, ctx);
            mut index_str := codegen_generate_expression(index_idx, env, ctx);

            if is_arena == 1 {
                mut target_struct := "SessionNode";
                if idx_t.tag == 7 { // Index
                    target_struct = idx_t.Index.struct_name;
                }
                mut erased_target := codegen_get_erased_struct_name(target_struct, env, ctx);

                mut dummy_t: ast.Type[ctx];
                if std.str_eq(erased_target, "int") == 1 {
                    dummy_t.tag = 0; // Int
                } else {
                    if std.str_eq(erased_target, "byte") == 1 {
                        dummy_t.tag = 1; // Byte
                    } else {
                        if std.str_eq(erased_target, "bool") == 1 {
                            dummy_t.tag = 2; // Bool
                        } else {
                            if std.str_eq(erased_target, "str") == 1 {
                                dummy_t.tag = 5; // Str
                            } else {
                                if std.str_eq(erased_target, "Any") == 1 {
                                    dummy_t.tag = 8;
                                    dummy_t.Struct.struct_name = "SessionNode";
                                    dummy_t.Struct.brand = empty[Index[str, ctx]];
                                } else { 
                                    dummy_t.tag = 8;
                                    dummy_t.Struct.struct_name = erased_target;
                                    dummy_t.Struct.brand = empty[Index[str, ctx]];
                                }
                            }
                        }
                    }
                }
                mut c_target := codegen_get_c_type(dummy_t, env, ctx);

                mut arrow_or_dot := ".";
                if alloc_t.tag == 9 || alloc_t.tag == 11 { // RawPointer or Reference
                    arrow_or_dot = "->";
                }

                mut res := std.Concat("(*((", c_target);
                res = std.Concat(res, "*)((char*)");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, arrow_or_dot);
                res = std.Concat(
                    res,
                    "BaseAddress + (size_t)(uint32_t)("
                );
                res = std.Concat(res, index_str);
                res = std.Concat(res, "))))");
                return std.Clone(ctx, res);
            }

            if codegen_is_slice_type(alloc_t, env, ctx) == 1 {
                mut res := std.Concat("(*({ if (", index_str);
                res = std.Concat(res, " < 0 || ");
                res = std.Concat(res, index_str);
                res = std.Concat(res, " >= ");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, ".len) { printf(\"Slice bounds check failed at line %d\\n\", __LINE__); exit(1); } &(");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, ".data[");
                res = std.Concat(res, index_str);
                res = std.Concat(res, "]); }))");
                return std.Clone(ctx, res);
            }

            if codegen_is_ptr_type(alloc_t, env, ctx) == 1 {
                mut res := std.Concat("(", alloc_str);
                res = std.Concat(res, "[");
                res = std.Concat(res, index_str);
                res = std.Concat(res, "])");
                return std.Clone(ctx, res);
            }

            if codegen_is_vector_type(alloc_t, env, ctx) == 1 {
                mut arrow_or_dot := ".";
                if alloc_t.tag == 9 || alloc_t.tag == 11 { // RawPointer or Reference
                    arrow_or_dot = "->";
                }
                mut res := std.Concat("(*({ if (", index_str);


                
                res = std.Concat(res, " < 0 || ");
                res = std.Concat(res, index_str);
                res = std.Concat(res, " >= ");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, arrow_or_dot);
                res = std.Concat(res, "len) { printf(\"Vector bounds check failed at line %d\\n\", __LINE__); exit(1); } &(");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, arrow_or_dot);
                res = std.Concat(res, "data[");
                res = std.Concat(res, index_str);
                res = std.Concat(res, "]); }))");
                return std.Clone(ctx, res);
            }

            if codegen_is_pool_type(alloc_t, env, ctx) == 1 {
                mut arrow_or_dot := ".";
                if alloc_t.tag == 9 || alloc_t.tag == 11 { // RawPointer or Reference
                    arrow_or_dot = "->";
                }
                mut res := std.Concat("(*({ if (", index_str);
                res = std.Concat(res, " < 0 || ");
                res = std.Concat(res, index_str);
                res = std.Concat(res, " >= ");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, arrow_or_dot);
                res = std.Concat(res, "len) { printf(\"Pool bounds check failed at line %d\\n\", __LINE__); exit(1); } &(");
                res = std.Concat(res, alloc_str);
                res = std.Concat(res, arrow_or_dot);
                res = std.Concat(res, "data[");
                res = std.Concat(res, index_str);
                res = std.Concat(res, "]); }))");
                return std.Clone(ctx, res);
            }



            if codegen_is_hashmap_type(alloc_t, env, ctx) == 1 {
                mut alloc_representation := codegen_plan_argument_representation_for_type(alloc_t, env, ctx);
                mut alloc_argument := codegen_emit_argument_representation(alloc_str, alloc_representation, ctx);
                mut is_str_key := "0";
                if codegen_hashmap_is_str_key(alloc_t, env, ctx) == 1 {
                    is_str_key = "1";
                }
                mut res := std.Concat("(*os_HashMapRef(", alloc_argument);
                res = std.Concat(res, ", ");
                res = std.Concat(res, index_str);
                res = std.Concat(res, ", ");
                res = std.Concat(res, is_str_key);
                res = std.Concat(res, "))");
                return std.Clone(ctx, res);
            }

            mut res := std.Concat(alloc_str, "[");
            res = std.Concat(res, index_str);
            res = std.Concat(res, "]");
            return std.Clone(ctx, res);
        }
        
                if tag == 9 { // AsCast
            mut left_idx := ctx[expr_idx].AsCast.left;
            mut left_expr := ctx[left_idx];
            mut old_alloc_struct := "";
            mut has_alloc_override := 0;

            if left_expr.tag == 12 { // Call
                mut func_str := typechecker.get_call_func_name(left_expr.Call.function, ctx);
                mut resolved_func := typechecker.env_resolve_namespaced_ident(env, func_str, ctx);
                if std.str_eq(resolved_func, "os_ArenaAlloc") == 1 || std.str_eq(resolved_func, "os.ArenaAlloc") == 1 ||
                   std.str_eq(resolved_func, "os_ScratchAlloc") == 1 || std.str_eq(resolved_func, "os.ScratchAlloc") == 1 {
                    mut target_type_idx := ctx[expr_idx].AsCast.target_type;
                    mut target_type := ctx[target_type_idx];
                    mut resolved_target_type := typechecker.env_resolve_type(env, target_type, ctx);
                    mut erased_target_type := codegen_erase_type(resolved_target_type, env, ctx);

                    mut struct_name := "";
                    if erased_target_type.tag == 8 { // Struct
                        struct_name = erased_target_type.Struct.struct_name;
                    } else {
                        if erased_target_type.tag == 7 { // Index
                            struct_name = erased_target_type.Index.struct_name;
                        }
                    }
                    old_alloc_struct = (*env).current_alloc_struct;
                    (*env).current_alloc_struct = struct_name;
                    has_alloc_override = 1;
                }
            }

            mut left_str := codegen_generate_expression(left_idx, env, ctx);

            if has_alloc_override == 1 {
                (*env).current_alloc_struct = old_alloc_struct;
            }

        mut target_str := codegen_get_c_type(ctx[ctx[expr_idx].AsCast.target_type], env, ctx);

                if ctx[expr_idx].AsCast.is_reference == 1 {
                    mut clean_target := codegen_strip_pointer_suffix(target_str, ctx);
                    mut block := std.Concat("(({ CastResult_", clean_target);
                    block = std.Concat(block, " res; res.Ok = ((((uintptr_t)");
                    block = std.Concat(block, left_str);
                    block = std.Concat(block, ".data) & (__alignof__(");
                    block = std.Concat(block, clean_target);
                    block = std.Concat(block, ") - 1)) == 0) && (");
                    block = std.Concat(block, left_str);
                    block = std.Concat(block, ".len >= sizeof(");
                    block = std.Concat(block, clean_target);
                    block = std.Concat(block, ")); res.Val = (");
                    block = std.Concat(block, clean_target);
                    block = std.Concat(block, "*)");
                    block = std.Concat(block, left_str);
                    block = std.Concat(block, ".data; res; }))");
                    return std.Clone(ctx, block);
                }

                mut res := std.Concat("((", target_str);
                res = std.Concat(res, ")");
                res = std.Concat(res, left_str);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
        }
        
        if tag == 10 { // Binary
            mut left_str := codegen_generate_expression(ctx[expr_idx].Binary.left, env, ctx);
            mut right_str := codegen_generate_expression(ctx[expr_idx].Binary.right, env, ctx);
            mut res := std.Concat("(", left_str);
            res = std.Concat(res, " ");
            res = std.Concat(res, ctx[expr_idx].Binary.op);
            res = std.Concat(res, " ");
            res = std.Concat(res, right_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if tag == 11 { // Selector
            mut left_str := codegen_generate_expression(ctx[expr_idx].Selector.left, env, ctx);
            mut left_t := codegen_get_expression_type(ctx[expr_idx].Selector.left, env, ctx);
            mut arrow_or_dot := ".";
            if left_t.tag == 9 || left_t.tag == 11 { // RawPointer = 9, Reference = 11
                arrow_or_dot = "->";
            }
            
            mut left_expr := ctx[expr_idx].Selector.left;
            if ctx[left_expr].tag == 11 { // Selector
                mut inner_left_expr := ctx[left_expr].Selector.left;
                mut inner_left_type := codegen_get_expression_type(inner_left_expr, env, ctx);
                if inner_left_type.tag == 8 { // Struct
                    mut struct_name := inner_left_type.Struct.struct_name;
                    mut clean_name := struct_name;
                    mut d_idx := std.str_find(struct_name, "__");
                    if d_idx != 0 - 1 { 
                        clean_name = std.str_slice(struct_name, d_idx + 2, len(struct_name));
                    }
                    if len(clean_name) >= 11 && std.str_eq(std.str_slice(clean_name, 0, 11), "CastResult_") == 1 {
                        if std.str_eq(ctx[left_expr].Selector.right, "Val") == 1 {
                            arrow_or_dot = "->";
                        }
                    }
                }
            }

            mut res := std.Concat(left_str, arrow_or_dot);
            res = std.Concat(res, ctx[expr_idx].Selector.right);
            return std.Clone(ctx, res);
        }
        if tag == 12 { // Call
            // Intercept Mutex & Channel methods
            mut func_expr := ctx[ctx[expr_idx].Call.function];
            if func_expr.tag == 11 { // Selector
                mut left_expr_idx := func_expr.Selector.left;
                mut right_name := func_expr.Selector.right;
                mut left_type := codegen_get_expression_type(left_expr_idx, env, ctx);
                mut left_source_type := left_type;
                mut resolved_left_type := typechecker.env_resolve_type(env, left_type, ctx);
                mut is_ptr := 0;
                if left_type.tag == 9 { // RawPointer
                    left_type = ctx[left_type.RawPointer.inner];
                    is_ptr = 1;
                } else if left_type.tag == 11 { // Reference
                    left_type = ctx[left_type.Reference.inner];
                    is_ptr = 1;
                }
                mut is_arena := typechecker.typechecker_classify_resolved_type(resolved_left_type, typechecker.typechecker_classification_arena(), env, ctx);
                mut is_mutex := 0;
                mut is_channel := 0;
                mut is_vec := typechecker.typechecker_classify_resolved_type(resolved_left_type, typechecker.typechecker_classification_vector(), env, ctx);
                mut is_map := typechecker.typechecker_classify_resolved_type(resolved_left_type, typechecker.typechecker_classification_hashmap(), env, ctx);
                mut is_pool := typechecker.typechecker_classify_resolved_type(resolved_left_type, typechecker.typechecker_classification_pool(), env, ctx);
                mut is_rc := 0;
                mut is_graph := 0;
                mut is_gen_arena := 0;
                mut s_name := "";
                if left_type.tag == 8 { // Struct
                    s_name = left_type.Struct.struct_name;
                    mut clean := typechecker.typechecker_strip_module_prefix(s_name, ctx);
                    if std.str_find(clean, "Mutex_") == 0 || std.str_find(clean, "std_Mutex_") == 0 { 
                        is_mutex = 1;
                    }
                    if std.str_find(clean, "Channel_") == 0 || std.str_find(clean, "std_Channel_") == 0 { 
                        is_channel = 1;
                    }
                    if std.str_find(clean, "Rc_") == 0 || std.str_find(clean, "std_Rc_") == 0 { 
                        is_rc = 1;
                    }
                    if std.str_find(clean, "Graph_") == 0 || std.str_find(clean, "std_Graph_") == 0 { 
                        is_graph = 1;
                    }
                    if std.str_find(clean, "GenerationalArena_") == 0 || std.str_find(clean, "std_GenerationalArena_") == 0 { 
                        is_gen_arena = 1;
                    }
                }

                if is_mutex == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut arrow_or_dot := ".";
                    if is_ptr == 1 {
                        arrow_or_dot = "->";
                    }
                    if std.str_eq(right_name, "Lock") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Mutex Lock FFI override for %s", left_str), ctx);
                        mut res := std.Concat("std_Mutex_Lock_impl(", left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "lock_state, &(");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "value))");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Unlock") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Mutex Unlock FFI override for %s", left_str), ctx);
                        mut res := std.Concat("std_Mutex_Unlock_impl(", left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "lock_state)");
                        return std.Clone(ctx, res);
                    }
                }

                if is_channel == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut arrow_or_dot := ".";
                    if is_ptr == 1 {
                        arrow_or_dot = "->";
                    }
                    if std.str_eq(right_name, "Send") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Channel Send FFI override for %s", left_str), ctx);
                        mut args_vec_channel_send: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_channel_send[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);

                        mut res := std.Concat("(({ __typeof__(", arg_str);
                        res = std.Concat(res, ") _tmp = ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, "; std_Channel_Send_impl(");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "capacity, &_tmp); }))");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Recv") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Channel Recv FFI override for %s", left_str), ctx);
                        mut type_str := codegen_get_c_type(left_type, env, ctx);
                        mut res := std.Concat("(({ __typeof__(*(((struct ", type_str);
                        res = std.Concat(res, "*)0)->_phantom)) _val; std_Channel_Recv_impl(");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "capacity, &_val); _val; }))");
                        return std.Clone(ctx, res);
                    }
                }

                if is_vec == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_type(left_source_type, env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    if std.str_eq(right_name, "Push") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector Push FFI override for %s", left_str), ctx);
                        mut args_vec_vector_push: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_vector_push[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("os_VectorPush(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Set") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector Set explicit write override for %s", left_str), ctx);
                        mut args_vec_vector_set: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];

                        mut idx_arg_idx_vector_set: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(idx_arg_idx_vector_set, args_vec_vector_set[0]);
                        mut idx_str_vector_set := codegen_generate_expression(idx_arg_idx_vector_set, env, ctx);

                        mut value_arg_idx_vector_set: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(value_arg_idx_vector_set, args_vec_vector_set[1]);
                        mut value_str_vector_set := codegen_generate_expression(value_arg_idx_vector_set, env, ctx);

                        mut vector_set_arrow_or_dot := ".";
                        if is_ptr == 1 {
                            vector_set_arrow_or_dot = "->";
                        }

                        mut vector_set_res := std.Concat("({ int _gust_vector_set_idx = ", idx_str_vector_set);
                        vector_set_res = std.Concat(vector_set_res, "; if (_gust_vector_set_idx < 0 || _gust_vector_set_idx >= ");
                        vector_set_res = std.Concat(vector_set_res, left_str);
                        vector_set_res = std.Concat(vector_set_res, vector_set_arrow_or_dot);
                        vector_set_res = std.Concat(vector_set_res, "len) { printf(\"Vector bounds check failed at line %d\\n\", __LINE__); exit(1); } ");
                        vector_set_res = std.Concat(vector_set_res, left_str);
                        vector_set_res = std.Concat(vector_set_res, vector_set_arrow_or_dot);
                        vector_set_res = std.Concat(vector_set_res, "data[_gust_vector_set_idx] = ");
                        vector_set_res = std.Concat(vector_set_res, value_str_vector_set);
                        vector_set_res = std.Concat(vector_set_res, "; })");
                        return std.Clone(ctx, vector_set_res);
                    }
                    if std.str_eq(right_name, "Pop") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector Pop FFI override for %s", left_str), ctx);
                        mut res := std.Concat("os_VectorPop(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Clear") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector Clear FFI override for %s", left_str), ctx);
                        mut res := std.Concat("os_VectorClear(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Back") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector Back FFI override for %s", left_str), ctx);
                        mut res := std.Concat("os_VectorBack(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "get_opt") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector get_opt Option override for %s", left_str), ctx);
                        mut args_vec_vector_getopt: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx_getopt: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx_getopt, args_vec_vector_getopt[0]);
                        mut idx_str_getopt := codegen_generate_expression(arg0_idx_getopt, env, ctx);

                        mut expr_type_getopt := codegen_get_expression_type(expr_idx, env, ctx);
                        expr_type_getopt = typechecker.env_resolve_type(env, expr_type_getopt, ctx);
                        mut option_c_type_getopt := codegen_get_c_type(expr_type_getopt, env, ctx);

                        mut vector_getopt_arrow_or_dot := ".";
                        if is_ptr == 1 {
                            vector_getopt_arrow_or_dot = "->";
                        }

                        mut vector_get_opt_res := std.Concat("({ ", option_c_type_getopt);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, " _gust_get_opt_result; int _gust_get_opt_idx = ");
                        vector_get_opt_res = std.Concat(vector_get_opt_res, idx_str_getopt);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, "; if (_gust_get_opt_idx < 0 || _gust_get_opt_idx >= ");
                        vector_get_opt_res = std.Concat(vector_get_opt_res, left_str);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, vector_getopt_arrow_or_dot);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, "len) { _gust_get_opt_result.tag = ");
                        vector_get_opt_res = std.Concat(vector_get_opt_res, option_c_type_getopt);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, "_Tag__None; } else { _gust_get_opt_result.tag = ");
                        vector_get_opt_res = std.Concat(vector_get_opt_res, option_c_type_getopt);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, "_Tag__Some; _gust_get_opt_result.Some.val = ");
                        vector_get_opt_res = std.Concat(vector_get_opt_res, left_str);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, vector_getopt_arrow_or_dot);
                        vector_get_opt_res = std.Concat(vector_get_opt_res, "data[_gust_get_opt_idx]; } _gust_get_opt_result; })");
                        return std.Clone(ctx, vector_get_opt_res);
                    }
                    if std.str_eq(right_name, "GetRef") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Vector GetRef FFI override for %s", left_str), ctx);
                        mut args_vec_vector_getref: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_vector_getref[0]);
                        mut idx_str := codegen_generate_expression(arg0_idx, env, ctx);

                        mut expr_type := codegen_get_expression_type(expr_idx, env, ctx);
                        mut inner_type: ast.Type[ctx];
                        if expr_type.tag == 11 { // Reference
                            inner_type = ctx[expr_type.Reference.inner];
                        } else {
                            // Defensive fallback: Step 2 should type this call as &T[ctx].
                            inner_type = typechecker.typechecker_get_template_elem_type(s_name, "data", env, ctx);
                        }
                        mut vector_get_ref_c_type := codegen_get_c_type(inner_type, env, ctx);

                        mut vector_get_ref_arrow_or_dot := ".";
                        if is_ptr == 1 {
                            vector_get_ref_arrow_or_dot = "->";
                        }

                        mut vector_get_ref_res := std.Concat("((", vector_get_ref_c_type);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, "*)({ if (");
                        vector_get_ref_res = std.Concat(vector_get_ref_res, idx_str);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, " < 0 || ");
                        vector_get_ref_res = std.Concat(vector_get_ref_res, idx_str);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, " >= ");
                        vector_get_ref_res = std.Concat(vector_get_ref_res, left_str);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, vector_get_ref_arrow_or_dot);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, "len) { printf(\"Vector bounds check failed at line %d\\n\", __LINE__); exit(1); } &(");
                        vector_get_ref_res = std.Concat(vector_get_ref_res, left_str);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, vector_get_ref_arrow_or_dot);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, "data[");
                        vector_get_ref_res = std.Concat(vector_get_ref_res, idx_str);
                        vector_get_ref_res = std.Concat(vector_get_ref_res, "]); }))");
                        return std.Clone(ctx, vector_get_ref_res);
                    }
                }

                if is_map == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut is_str_key := 0;
                    mut erased_s_name := codegen_get_erased_struct_name(s_name, env, ctx);
                    mut orig_s_name := codegen_find_original_struct_name(erased_s_name, env, ctx);
                    mut lookup_struct := (*env).struct_registry.get_opt(orig_s_name);
                    match lookup_struct {
                        Some { val } => {
                            mut layout := *val;
                            mut keys_type_lookup := layout.fields.get_opt("keys");
                            match keys_type_lookup {
                                Some { val } => {
                                    mut keys_type := *val;
                                    if keys_type.tag == 9 { // RawPointer
                                        mut key_elem_type := ctx[keys_type.RawPointer.inner];
                                        if key_elem_type.tag == 5 { // Str
                                            is_str_key = 1;
                                        }
                                    }
                                }
                                None => {
                                }
                            }
                        }
                        None => {
                        }
                    }

                    mut left_representation := codegen_plan_argument_representation_for_type(left_source_type, env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    mut is_str_key_str := "0";
                    if is_str_key == 1 {
                        is_str_key_str = "1";
                    }

                    if std.str_eq(right_name, "Insert") || std.str_eq(right_name, "Set") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap Insert/Set FFI override for %s", left_str), ctx);
                        mut args_vec_map_insert: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_map_insert[0]);
                        mut k_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg1_idx, args_vec_map_insert[1]);
                        mut v_str := codegen_generate_expression(arg1_idx, env, ctx);
                        
                        mut res := std.Concat("*os_HashMapRef(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, k_str);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, is_str_key_str);
                        res = std.Concat(res, ") = ");
                        res = std.Concat(res, v_str);
                        return std.Clone(ctx, res);
                    }
                    if (std.str_eq(right_name, "Get")) { 
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap Get FFI override for %s", left_str), ctx);
                        mut args_vec_map_get: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_map_get[0]);
                        mut k_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut val_type_ident := "int";
                        match lookup_struct {
                            Some { val } => {
                                mut layout := *val;
                                mut val_type_lookup := layout.fields.get_opt("values");
                                match val_type_lookup {
                                    Some { val } => {
                                        mut val_type := *val;
                                        if val_type.tag == 9 { // RawPointer
                                            mut val_elem_type := ctx[val_type.RawPointer.inner];
                                            mut erased_val_elem_type := codegen_erase_type(val_elem_type, env, ctx);
                                            val_type_ident = typechecker.get_type_ident(erased_val_elem_type, ctx);
                                        } 
                                    }
                                    None => {
                                    }
                                }
                            }
                            None => {
                            }
                        }
                        
                        mut lookup_struct_name := std.Concat("LookupResult_", val_type_ident);
                        
                        mut res := std.Concat("({ ", lookup_struct_name);
                        res = std.Concat(res, " res = {0}; res.Ok = os_HashMapContains(");
                        res = std.Concat(res, left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, k_str);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, is_str_key_str);
                        res = std.Concat(res, "); if (res.Ok) { res.Val = *os_HashMapRef(");
                        res = std.Concat(res, left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, k_str);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, is_str_key_str);
                        res = std.Concat(res, "); } res; })");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "GetRef") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap GetRef FFI override for %s", left_str), ctx);
                        mut args_vec_map_getref: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx_getref_map: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx_getref_map, args_vec_map_getref[0]);
                        mut k_str_getref_map := codegen_generate_expression(arg0_idx_getref_map, env, ctx);

                        mut expr_type_getref_map := codegen_get_expression_type(expr_idx, env, ctx);
                        expr_type_getref_map = typechecker.env_resolve_type(env, expr_type_getref_map, ctx);
                        mut inner_type_getref_map: ast.Type[ctx];
                        if expr_type_getref_map.tag == 11 { // Reference
                            inner_type_getref_map = ctx[expr_type_getref_map.Reference.inner];
                        } else {
                            inner_type_getref_map = typechecker.typechecker_get_template_elem_type(s_name, "values", env, ctx);
                        }
                        mut hashmap_get_ref_c_type := codegen_get_c_type(inner_type_getref_map, env, ctx);

                        mut res_getref_map := std.Concat("((", hashmap_get_ref_c_type);
                        res_getref_map = std.Concat(res_getref_map, "*)({ if (!os_HashMapContains(");
                        res_getref_map = std.Concat(res_getref_map, left_argument);
                        res_getref_map = std.Concat(res_getref_map, ", ");
                        res_getref_map = std.Concat(res_getref_map, k_str_getref_map);
                        res_getref_map = std.Concat(res_getref_map, ", ");
                        res_getref_map = std.Concat(res_getref_map, is_str_key_str);
                        res_getref_map = std.Concat(res_getref_map, ")) { printf(\"HashMap GetRef missing key at line %d\\n\", __LINE__); exit(1); } os_HashMapRef(");
                        res_getref_map = std.Concat(res_getref_map, left_argument);
                        res_getref_map = std.Concat(res_getref_map, ", ");
                        res_getref_map = std.Concat(res_getref_map, k_str_getref_map);
                        res_getref_map = std.Concat(res_getref_map, ", ");
                        res_getref_map = std.Concat(res_getref_map, is_str_key_str);
                        res_getref_map = std.Concat(res_getref_map, "); }))");
                        return std.Clone(ctx, res_getref_map);
                    }
                    if std.str_eq(right_name, "get_opt") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap get_opt Option override for %s", left_str), ctx);
                        mut args_vec_map_getopt: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx_getopt_map: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx_getopt_map, args_vec_map_getopt[0]);
                        mut k_str_getopt_map := codegen_generate_expression(arg0_idx_getopt_map, env, ctx);

                        mut expr_type_getopt_map := codegen_get_expression_type(expr_idx, env, ctx);
                        expr_type_getopt_map = typechecker.env_resolve_type(env, expr_type_getopt_map, ctx);
                        mut option_c_type_getopt_map := codegen_get_c_type(expr_type_getopt_map, env, ctx);

                        mut res_getopt_map := std.Concat("({ ", option_c_type_getopt_map);
                        res_getopt_map = std.Concat(res_getopt_map, " _gust_map_get_opt_result = {0}; int _gust_map_get_opt_ok = os_HashMapContains(");
                        res_getopt_map = std.Concat(res_getopt_map, left_argument);
                        res_getopt_map = std.Concat(res_getopt_map, ", ");
                        res_getopt_map = std.Concat(res_getopt_map, k_str_getopt_map);
                        res_getopt_map = std.Concat(res_getopt_map, ", ");
                        res_getopt_map = std.Concat(res_getopt_map, is_str_key_str);
                        res_getopt_map = std.Concat(res_getopt_map, "); if (_gust_map_get_opt_ok) { _gust_map_get_opt_result.tag = ");
                        res_getopt_map = std.Concat(res_getopt_map, option_c_type_getopt_map);
                        res_getopt_map = std.Concat(res_getopt_map, "_Tag__Some; _gust_map_get_opt_result.Some.val = *os_HashMapRef(");
                        res_getopt_map = std.Concat(res_getopt_map, left_argument);
                        res_getopt_map = std.Concat(res_getopt_map, ", ");
                        res_getopt_map = std.Concat(res_getopt_map, k_str_getopt_map);
                        res_getopt_map = std.Concat(res_getopt_map, ", ");
                        res_getopt_map = std.Concat(res_getopt_map, is_str_key_str);
                        res_getopt_map = std.Concat(res_getopt_map, "); } else { _gust_map_get_opt_result.tag = ");
                        res_getopt_map = std.Concat(res_getopt_map, option_c_type_getopt_map);
                        res_getopt_map = std.Concat(res_getopt_map, "_Tag__None; } _gust_map_get_opt_result; })");
                        return std.Clone(ctx, res_getopt_map);
                    }
                    if std.str_eq(right_name, "Remove") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap Remove FFI override for %s", left_str), ctx);
                        mut args_vec_map_remove: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_map_remove[0]);
                        mut k_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("os_HashMapRemove(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, k_str);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, is_str_key_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Clear") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling HashMap Clear FFI override for %s", left_str), ctx);
                        mut res := std.Concat("os_HashMapClear(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }


                    if (std.str_eq(right_name, "Keys")) {
                        mut args_vec_map_keys: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_map_keys[0]);
                        mut ctx_str := codegen_generate_expression(arg0_idx, env, ctx);

                        mut expr_type := codegen_get_expression_type(expr_idx, env, ctx);
                        mut vec_type_str := "";
                        if (expr_type.tag == 3) { // Void - fallback
                            mut key_type_ident := "int";
                            match lookup_struct {
                                Some { val } => {
                                    mut layout := *val;
                                    mut keys_type_lookup := layout.fields.get_opt("keys");
                                    match keys_type_lookup {
                                        Some { val } => {
                                            mut keys_type := *val;
                                            if keys_type.tag == 9 { // RawPointer
                                                mut key_elem_type := ctx[keys_type.RawPointer.inner];
                                                mut erased_key_elem_type := codegen_erase_type(key_elem_type, env, ctx);
                                                key_type_ident = typechecker.get_type_ident(erased_key_elem_type, ctx);
                                            }
                                        }
                                        None => {
                                        }
                                    }
                                }
                                None => {
                                }
                            }
                            mut brand_name := "ctx";
                            mut arg0_type := codegen_get_expression_type(arg0_idx, env, ctx);
                            if arg0_type.tag == 8 { // Struct
                                brand_name = arg0_type.Struct.struct_name;
                            } else if arg0_type.tag == 9 { // RawPointer
                                mut inner_t := ctx[arg0_type.RawPointer.inner];
                                if inner_t.tag == 8 {
                                    brand_name = inner_t.Struct.struct_name;
                                }
                            }
                            if std.str_eq(brand_name, "Arena") == 1 || std.str_eq(brand_name, "os_Arena") == 1 {
                                brand_name = "ctx";
                            }
                            vec_type_str = std.Concat("std_Vector_", key_type_ident);
                            vec_type_str = std.Concat(vec_type_str, "_");
                            vec_type_str = std.Concat(vec_type_str, brand_name);
                        } else {
                            vec_type_str = codegen_get_c_type(expr_type, env, ctx);
                        }

                    
                        
                        mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                        mut arena_expr := codegen_emit_argument_representation(ctx_str, arena_representation, ctx);
                        
                        mut arrow_or_dot := ".";
                        if is_ptr == 1 {
                            arrow_or_dot = "->";
                        }
                        
                        mut res := std.Concat("(({ ", vec_type_str);
                        res = std.Concat(res, " _v = (");
                        res = std.Concat(res, vec_type_str);
                        res = std.Concat(res, "){ .data = NULL, .len = 0, .capacity = 0, .arena = ");
                        res = std.Concat(res, arena_expr);
                        res = std.Concat(res, " }; for (int _i = 0; _i < (");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "capacity); _i++) { if ((");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "occupied)[_i] == 1) { os_VectorPush(&_v, (");
                        res = std.Concat(res, left_str);
                        res = std.Concat(res, arrow_or_dot);
                        res = std.Concat(res, "keys)[_i]); } } _v; }))");
                        return std.Clone(ctx, res);
                    }
                }

                if is_pool == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_type(left_source_type, env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    if std.str_eq(right_name, "Alloc") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Pool Alloc FFI override for %s", left_str), ctx);
                        mut args_vec_pool_alloc: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_pool_alloc[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("std_PoolAlloc(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Free") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Pool Free FFI override for %s", left_str), ctx);
                        mut args_vec_pool_free: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_pool_free[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("std_PoolFree(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                }

                if is_rc == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_value_class(left_source_type, "reference_receiver", env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    if std.str_eq(right_name, "Clone") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Rc Clone FFI override for %s", left_str), ctx);
                        mut res := std.Concat("std_RcClone(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Release") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Rc Release FFI override for %s", left_str), ctx);
                        mut res := std.Concat("std_RcRelease(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "Get") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Rc Get FFI override for %s", left_str), ctx);
                        mut res := std.Concat("std_RcGet(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                }

                if is_graph == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_value_class(left_source_type, "reference_receiver", env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    if std.str_eq(right_name, "AddNode") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Graph AddNode FFI override for %s", left_str), ctx);
                        mut args_vec_graph_add_node: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_graph_add_node[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("std_GraphAddNode(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "AddEdge") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Graph AddEdge FFI override for %s", left_str), ctx);
                        mut args_vec_graph_add_edge: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_graph_add_edge[0]);
                        mut arg0_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg1_idx, args_vec_graph_add_edge[1]);
                        mut arg1_str := codegen_generate_expression(arg1_idx, env, ctx);
                        
                        mut res := std.Concat("std_GraphAddEdge(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg0_str);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg1_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    if std.str_eq(right_name, "GetNode") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Graph GetNode FFI override for %s", left_str), ctx);
                        mut args_vec_graph_get_node: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_graph_get_node[0]);
                        mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                        mut res := std.Concat("std_GraphGetNode(", left_argument);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                }

                if is_gen_arena == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_value_class(left_source_type, "reference_receiver", env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);
                    if std.str_eq(right_name, "Step") || std.str_eq(right_name, "step") || std.str_eq(right_name, "Swap") || std.str_eq(right_name, "swap") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling GenerationalArena Step FFI override for %s", left_str), ctx);
                        mut t_name := "Node";
                        mut res := std.Concat("std_GenerationalArena_Step_", t_name);
                        res = std.Concat(res, "(");
                        res = std.Concat(res, left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                }

                if is_arena == 1 {
                    mut left_str := codegen_generate_expression(left_expr_idx, env, ctx);
                    mut left_representation := codegen_plan_argument_representation_for_type(left_source_type, env, ctx);
                    mut left_argument := codegen_emit_argument_representation(left_str, left_representation, ctx);

                    if std.str_eq(right_name, "get_ref") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Arena get_ref FFI override for %s", left_str), ctx);
                        mut args_vec_arena_get_ref: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(arg0_idx, args_vec_arena_get_ref[0]);
                        mut idx_str := codegen_generate_expression(arg0_idx, env, ctx);

                        mut expr_type := codegen_get_expression_type(expr_idx, env, ctx);
                        mut inner_type: ast.Type[ctx];
                        if expr_type.tag == 11 { // Reference
                            inner_type = ctx[expr_type.Reference.inner];
                        } else {
                            inner_type.tag = 3; // Void fallback; Step 1 should resolve this as Reference.
                        }
                        mut arena_get_ref_c_type := codegen_get_c_type(inner_type, env, ctx);

                        mut arena_get_ref_arrow_or_dot := ".";
                        if is_ptr == 1 {
                            arena_get_ref_arrow_or_dot = "->";
                        }

                        mut arena_get_ref_res := std.Concat("((", arena_get_ref_c_type);
                        arena_get_ref_res = std.Concat(arena_get_ref_res, "*)((char*)");
                        arena_get_ref_res = std.Concat(arena_get_ref_res, left_str);
                        arena_get_ref_res = std.Concat(arena_get_ref_res, arena_get_ref_arrow_or_dot);
                        arena_get_ref_res = std.Concat(
                            arena_get_ref_res,
                            "BaseAddress + (size_t)(uint32_t)("
                        );
                        arena_get_ref_res = std.Concat(
                            arena_get_ref_res,
                            idx_str
                        );
                        arena_get_ref_res = std.Concat(
                            arena_get_ref_res,
                            ")))"
                        );
                        return std.Clone(ctx, arena_get_ref_res);
                    }

                    if std.str_eq(right_name, "Set") || std.str_eq(right_name, "Write") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Arena explicit write FFI override for %s", left_str), ctx);
                        mut args_vec_arena_set: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                        mut idx_arg_idx_arena_set: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(idx_arg_idx_arena_set, args_vec_arena_set[0]);
                        mut idx_str_arena_set := codegen_generate_expression(idx_arg_idx_arena_set, env, ctx);

                        mut value_arg_idx_arena_set: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx.Set(value_arg_idx_arena_set, args_vec_arena_set[1]);
                        mut value_str_arena_set := codegen_generate_expression(value_arg_idx_arena_set, env, ctx);

                        mut idx_type_arena_set := codegen_get_expression_type(idx_arg_idx_arena_set, env, ctx);
                        idx_type_arena_set = typechecker.env_resolve_type(env, idx_type_arena_set, ctx);
                        mut elem_type_arena_set := typechecker.typechecker_get_index_element_type(idx_type_arena_set, env, ctx);
                        elem_type_arena_set = typechecker.env_resolve_type(env, elem_type_arena_set, ctx);
                        mut arena_set_c_type := codegen_get_c_type(elem_type_arena_set, env, ctx);

                        mut arena_set_arrow_or_dot := ".";
                        if is_ptr == 1 {
                            arena_set_arrow_or_dot = "->";
                        }

                        mut arena_set_res := std.Concat("({ *((", arena_set_c_type);
                        arena_set_res = std.Concat(arena_set_res, "*)((char*)");
                        arena_set_res = std.Concat(arena_set_res, left_str);
                        arena_set_res = std.Concat(arena_set_res, arena_set_arrow_or_dot);
                        arena_set_res = std.Concat(
                            arena_set_res,
                            "BaseAddress + (size_t)(uint32_t)("
                        );
                        arena_set_res = std.Concat(
                            arena_set_res,
                            idx_str_arena_set
                        );
                        arena_set_res = std.Concat(
                            arena_set_res,
                            "))) = "
                        );
                        arena_set_res = std.Concat(arena_set_res, value_str_arena_set);
                        arena_set_res = std.Concat(arena_set_res, "; })");
                        return std.Clone(ctx, arena_set_res);
                    }

                    if std.str_eq(right_name, "Free") {
                        codegen_log_trace("👁️", std.Format("codegen_generate_expression: transpiling Arena Free FFI override for %s", left_str), ctx);
                        mut res := std.Concat("os_Arena_Free(", left_argument);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                }
            }

            mut func_str := codegen_generate_expression(ctx[expr_idx].Call.function, env, ctx);

            if std.str_eq(func_str, "std.RcNew") || std.str_eq(func_str, "std_RcNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.RcNew FFI override", ctx);
                mut args_vec_rc_new: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut pool_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(pool_expr_idx, args_vec_rc_new[0]);
                mut pool_expr := codegen_generate_expression(pool_expr_idx, env, ctx);
                
                mut val_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(val_expr_idx, args_vec_rc_new[1]);
                mut val_expr := codegen_generate_expression(val_expr_idx, env, ctx);

                mut pool_type := codegen_get_expression_type(pool_expr_idx, env, ctx);
                mut val_type := codegen_get_expression_type(val_expr_idx, env, ctx);

                mut ctx_name := "ctx";
                mut target_pool_type := pool_type;
                if target_pool_type.tag == 9 { // RawPointer
                    target_pool_type = ctx[target_pool_type.RawPointer.inner];
                } else if target_pool_type.tag == 11 { // Reference
                    target_pool_type = ctx[target_pool_type.Reference.inner];
                }

                if target_pool_type.tag == 8 { // Struct
                    mut struct_name := target_pool_type.Struct.struct_name;
                    mut brand_idx := target_pool_type.Struct.brand;
                    if brand_idx != empty[Index[str, ctx]] {
                        mut brand_name_rc_pool: str := ctx[brand_idx];
                        ctx_name = typechecker.strip_brand_prefix(brand_name_rc_pool, ctx);
                    }
                } else if target_pool_type.tag == 10 { // Generic
                    mut args_vec_rc_pool_type: std.Vector[ast.Type[ctx], ctx] := ctx[target_pool_type.Generic.args];
                    if len(args_vec_rc_pool_type) == 2 {
                        mut arg1 := args_vec_rc_pool_type[1];
                        if arg1.tag == 8 { // Struct
                            ctx_name = typechecker.strip_brand_prefix(arg1.Struct.struct_name, ctx);
                        }
                    }
                }

                mut val_ident := typechecker.get_type_ident(val_type, ctx);
                mut rc_type := std.Concat("std_Rc_", val_ident);
                rc_type = std.Concat(rc_type, "_");
                rc_type = std.Concat(rc_type, ctx_name);

                mut erased_rc_type := codegen_erase_struct_name(rc_type, empty[Index[str, ctx]], env, ctx);

                mut pool_representation := codegen_plan_argument_representation_for_value_class(pool_type, "reference_receiver", env, ctx);
                mut pool_ptr_expr := codegen_emit_argument_representation(pool_expr, pool_representation, ctx);

                mut res := std.Concat("std_RcNew(", pool_ptr_expr);
                res = std.Concat(res, ", ");
                res = std.Concat(res, val_expr);
                res = std.Concat(res, ", ");
                res = std.Concat(res, erased_rc_type);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "len") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling len FFI override", ctx);
                mut args_vec_len_call: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_len_call[0]);
                mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                        
                mut arg_type := codegen_get_expression_type(arg0_idx, env, ctx);
                mut arrow_or_dot := ".";
                if arg_type.tag == 9 || arg_type.tag == 11 { // RawPointer or Reference
                    arrow_or_dot = "->";
                }
                        
                mut res := std.Concat(arg_str, arrow_or_dot);
                res = std.Concat(res, "len");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.str_split") || std.str_eq(func_str, "std_str_split") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.str_split FFI override", ctx);
                mut args_vec_str_split: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_str_split[0]);
                mut s_expr := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_str_split[1]);
                mut delim_expr := codegen_generate_expression(arg1_idx, env, ctx);

                mut arg2_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg2_idx, args_vec_str_split[2]);
                mut ctx_expr := codegen_generate_expression(arg2_idx, env, ctx);

                mut expr_type := codegen_get_expression_type(expr_idx, env, ctx);
                mut vec_type_str := "";
                if expr_type.tag == 3 { // Void - fallback
                    mut arg2_type := codegen_get_expression_type(arg2_idx, env, ctx);
                    mut brand_name := "ctx";
                    if arg2_type.tag == 8 { // Struct
                        brand_name = arg2_type.Struct.struct_name;
                    } else if arg2_type.tag == 9 { // RawPointer
                        mut inner_t := ctx[arg2_type.RawPointer.inner];
                        if inner_t.tag == 8 {
                            brand_name = inner_t.Struct.struct_name;
                        }
                    }
                    if std.str_eq(brand_name, "Arena") == 1 || std.str_eq(brand_name, "os_Arena") == 1 {
                        brand_name = "ctx";
                    }
                    vec_type_str = std.Concat("std_Vector_str_", brand_name);
                } else {
                    vec_type_str = codegen_get_c_type(expr_type, env, ctx);
                }

                mut arena_representation := codegen_plan_argument_representation(arg2_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(ctx_expr, arena_representation, ctx);

                mut res := std.Concat("(({ Slice_unsigned_char _s = ", s_expr);
                res = std.Concat(res, "; Slice_unsigned_char _delim = ");
                res = std.Concat(res, delim_expr);
                res = std.Concat(res, "; os_Arena* _ctx = ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, "; struct std_Vector_str _tmp = std_str_split(_s, _delim, _ctx); ((");
                res = std.Concat(res, vec_type_str);
                res = std.Concat(res, "){ .data = _tmp.data, .len = _tmp.len, .capacity = _tmp.capacity, .arena = _tmp.arena }); }))");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.Args") || std.str_eq(func_str, "os_Args") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.Args FFI override", ctx);
                mut args_vec_os_args: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_args[0]);
                mut ctx_expr := codegen_generate_expression(arg0_idx, env, ctx);

                mut expr_type := codegen_get_expression_type(expr_idx, env, ctx);
                mut vec_type_str := "";
                if expr_type.tag == 3 { // Void - fallback
                    mut arg0_type := codegen_get_expression_type(arg0_idx, env, ctx);
                    mut brand_name := "ctx";
                    if arg0_type.tag == 8 { // Struct
                        brand_name = arg0_type.Struct.struct_name;
                    } else if arg0_type.tag == 9 { // RawPointer
                        mut inner_t := ctx[arg0_type.RawPointer.inner];
                        if inner_t.tag == 8 {
                            brand_name = inner_t.Struct.struct_name;
                        }
                    }
                    if std.str_eq(brand_name, "Arena") == 1 || std.str_eq(brand_name, "os_Arena") == 1 {
                        brand_name = "ctx";
                    }
                    vec_type_str = std.Concat("std_Vector_str_", brand_name);
                } else {
                    vec_type_str = codegen_get_c_type(expr_type, env, ctx);
                }

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(ctx_expr, arena_representation, ctx);

                mut res := std.Concat("(({ os_Arena* _ctx = ", arena_expr);
                res = std.Concat(res, "; struct std_Vector_str _tmp = os_Args(_ctx); ((");
                res = std.Concat(res, vec_type_str);
                res = std.Concat(res, "){ .data = _tmp.data, .len = _tmp.len, .capacity = _tmp.capacity, .arena = _tmp.arena }); }))");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.Format") || std.str_eq(func_str, "std_Format") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.Format FFI override", ctx);
                mut args_vec_std_format: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                if len(args_vec_std_format) == 0 {
                    return std.Clone(ctx, "((Slice_unsigned_char){ NULL, 0 })");
                }

                mut format_arg_idx := 0;
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_std_format[0]);
                mut arg0_type := codegen_get_expression_type(arg0_idx, env, ctx);
                mut resolved_arg0 := typechecker.env_resolve_type(env, arg0_type, ctx);
                if resolved_arg0.tag == 4 || resolved_arg0.tag == 9 || resolved_arg0.tag == 11 { 
                    format_arg_idx = 1;
                }
                
                mut format_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(format_expr_idx, args_vec_std_format[format_arg_idx]);
                mut format_expr := ctx[format_expr_idx];
                
                mut format_str := "";
                if format_expr.tag == 2 { // String
                    format_str = format_expr.String.val;
                }
                
                mut size_expr := std.FormatInt(len(format_str));
                mut eval_statements := "";
                mut snprintf_args := "";
                mut c_format_string := "";
                
                mut idx := 0;
                mut spec_count := 0;
                while idx < len(format_str) {
                    mut b := std.str_byte_at(format_str, idx);
                    if b == 37 { // '%'
                        if idx + 1 < len(format_str) {
                            mut next_char := std.str_byte_at(format_str, idx + 1);
                            if next_char == 37 { // '%'
                                c_format_string = std.Concat(c_format_string, "%%");
                                idx = idx + 2;
                            } else {
                                spec_count = spec_count + 1;
                                mut arg_idx := spec_count + format_arg_idx;
                                mut arg_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                                ctx.Set(arg_expr_idx, args_vec_std_format[arg_idx]);
                                mut arg_str := codegen_generate_expression(arg_expr_idx, env, ctx);
                                
                                if next_char == 115 { // 's'
                                    c_format_string = std.Concat(c_format_string, "%.*s");
                                    
                                    mut arg_def := std.Concat("        Slice_unsigned_char _arg", std.FormatInt(arg_idx));
                                    arg_def = std.Concat(arg_def, " = ");
                                    arg_def = std.Concat(arg_def, arg_str);
                                    arg_def = std.Concat(arg_def, ";\n");
                                    eval_statements = std.Concat(eval_statements, arg_def);
                                    
                                    size_expr = std.Concat(size_expr, " + _arg");
                                    size_expr = std.Concat(size_expr, std.FormatInt(arg_idx));
                                    size_expr = std.Concat(size_expr, ".len");
                                    
                                    if std.str_eq(snprintf_args, "") == 0 {
                                        snprintf_args = std.Concat(snprintf_args, ", ");
                                    }
                                    snprintf_args = std.Concat(snprintf_args, "_arg");
                                    snprintf_args = std.Concat(snprintf_args, std.FormatInt(arg_idx));
                                    snprintf_args = std.Concat(snprintf_args, ".len, (char*)_arg");
                                    snprintf_args = std.Concat(snprintf_args, std.FormatInt(arg_idx));
                                    snprintf_args = std.Concat(snprintf_args, ".data");
                                } else { // treat as 'd'
                                    c_format_string = std.Concat(c_format_string, "%d");
                                    
                                    mut arg_def := std.Concat("        __typeof__(", arg_str);
                                    arg_def = std.Concat(arg_def, ") _arg");
                                    arg_def = std.Concat(arg_def, std.FormatInt(arg_idx));
                                    arg_def = std.Concat(arg_def, " = ");
                                    arg_def = std.Concat(arg_def, arg_str);
                                    arg_def = std.Concat(arg_def, ";\n");
                                    eval_statements = std.Concat(eval_statements, arg_def);
                                    
                                    size_expr = std.Concat(size_expr, " + 20");
                                    
                                    if std.str_eq(snprintf_args, "") == 0 {
                                        snprintf_args = std.Concat(snprintf_args, ", ");
                                    }
                                    snprintf_args = std.Concat(snprintf_args, "_arg");
                                    snprintf_args = std.Concat(snprintf_args, std.FormatInt(arg_idx));
                                }
                                idx = idx + 2;
                            } 
                        } else {
                            c_format_string = std.Concat(c_format_string, "%");
                            idx = idx + 1;
                        }
                    } else {
                        mut char_slice := std.str_slice(format_str, idx, idx + 1);
                        c_format_string = std.Concat(c_format_string, char_slice);
                        idx = idx + 1;
                    }
                }
                
                mut block := "(({ \n";
                block = std.Concat(block, eval_statements);
                block = std.Concat(block, "        int _alloc_size = ");
                block = std.Concat(block, size_expr);
                block = std.Concat(block, " + 1;\n");
                block = std.Concat(block, "        char* _buf = (char*)os_ScratchAlloc(_alloc_size);\n");
                
                mut snprintf_args_str := "";
                if std.str_eq(snprintf_args, "") == 0 {
                    snprintf_args_str = std.Concat(", ", snprintf_args);
                }
                
                block = std.Concat(block, "        int _len = snprintf(_buf, _alloc_size, \"");
                block = std.Concat(block, c_format_string);
                block = std.Concat(block, "\"");
                block = std.Concat(block, snprintf_args_str);
                block = std.Concat(block, ");\n");
                block = std.Concat(block, "        ((Slice_unsigned_char){ (unsigned char*)_buf, _len });\n");
                block = std.Concat(block, "    }))");
                return std.Clone(ctx, block);
            }

            if std.str_eq(func_str, "std.FormatInt") || std.str_eq(func_str, "std_FormatInt") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.FormatInt FFI override", ctx);
                mut args_vec_std_format_int: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_std_format_int[0]);
                mut val_expr := codegen_generate_expression(arg0_idx, env, ctx);
                
                mut res := std.Concat("(({ int _val = ", val_expr);
                res = std.Concat(res, "; char* _buf = (char*)os_ScratchAlloc(16); int _len = snprintf(_buf, 16, \"%d\", _val); ((Slice_unsigned_char){ (unsigned char*)_buf, _len }); }))");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.Concat") || std.str_eq(func_str, "std_Concat") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.Concat FFI override", ctx);
                mut args_vec_std_concat: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os_ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_std_concat[0]);
                mut s1_expr := codegen_generate_expression(arg0_idx, env, ctx);
                
                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os_ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_std_concat[1]);
                mut s2_expr := codegen_generate_expression(arg1_idx, env, ctx);
                
                mut res := std.Concat("(({ Slice_unsigned_char _s1 = ", s1_expr);
                res = std.Concat(res, "; Slice_unsigned_char _s2 = ");
                res = std.Concat(res, s2_expr);
                res = std.Concat(res, "; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); if (_s1.len > 0) memcpy(_buf, _s1.data, _s1.len); if (_s2.len > 0) memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){ (unsigned char*)_buf, _s1.len + _s2.len }); }))");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.GenerationalSwap") || std.str_eq(func_str, "std_GenerationalSwap") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.GenerationalSwap FFI override", ctx);
                mut args_vec_std_generational_swap: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_std_generational_swap[0]);
                mut arg0_str := codegen_generate_expression(arg0_idx, env, ctx);
                
                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_std_generational_swap[1]);
                mut arg1_str := codegen_generate_expression(arg1_idx, env, ctx);
                
                mut res := std.Concat("std_GenerationalSwap(&", arg0_str);
                res = std.Concat(res, ", &");
                res = std.Concat(res, arg1_str);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.VectorNew") || std.str_eq(func_str, "os_VectorNew") ||
               std.str_eq(func_str, "std.VectorNew") || std.str_eq(func_str, "std_VectorNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling VectorNew FFI override", ctx);
                mut args_vec_vector_new: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_vector_new[0]);
                mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);

                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_Vector_int", env, ctx
                );

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_str, arena_representation, ctx);

                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .data = NULL, .len = 0, .capacity = 0, .arena = ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, " })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.VectorGetRef") || std.str_eq(func_str, "std_VectorGetRef") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.VectorGetRef alias via Vector GetRef override", ctx);
                mut args_vec_vector_getref_alias: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];

                mut vec_arg_idx_vector_getref_alias: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(vec_arg_idx_vector_getref_alias, args_vec_vector_getref_alias[0]);
                mut vec_str_vector_getref_alias := codegen_generate_expression(vec_arg_idx_vector_getref_alias, env, ctx);

                mut idx_arg_idx_vector_getref_alias: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(idx_arg_idx_vector_getref_alias, args_vec_vector_getref_alias[1]);
                mut idx_str_vector_getref_alias := codegen_generate_expression(idx_arg_idx_vector_getref_alias, env, ctx);

                mut vec_type_vector_getref_alias := codegen_get_expression_type(vec_arg_idx_vector_getref_alias, env, ctx);
                mut vec_is_ptr_vector_getref_alias := 0;
                if vec_type_vector_getref_alias.tag == 9 { // RawPointer
                    vec_type_vector_getref_alias = ctx[vec_type_vector_getref_alias.RawPointer.inner];
                    vec_is_ptr_vector_getref_alias = 1;
                } else if vec_type_vector_getref_alias.tag == 11 { // Reference
                    vec_type_vector_getref_alias = ctx[vec_type_vector_getref_alias.Reference.inner];
                    vec_is_ptr_vector_getref_alias = 1;
                }

                mut vec_struct_name_vector_getref_alias := "";
                if vec_type_vector_getref_alias.tag == 8 { // Struct
                    vec_struct_name_vector_getref_alias = vec_type_vector_getref_alias.Struct.struct_name;
                }

                mut expr_type_vector_getref_alias := codegen_get_expression_type(expr_idx, env, ctx);
                mut inner_type_vector_getref_alias: ast.Type[ctx];
                if expr_type_vector_getref_alias.tag == 11 { // Reference
                    inner_type_vector_getref_alias = ctx[expr_type_vector_getref_alias.Reference.inner];
                } else {
                    inner_type_vector_getref_alias = typechecker.typechecker_get_template_elem_type(vec_struct_name_vector_getref_alias, "data", env, ctx);
                }
                mut vector_get_ref_alias_c_type := codegen_get_c_type(inner_type_vector_getref_alias, env, ctx);

                mut vector_get_ref_alias_arrow_or_dot := ".";
                if vec_is_ptr_vector_getref_alias == 1 {
                    vector_get_ref_alias_arrow_or_dot = "->";
                }

                mut vector_get_ref_alias_res := std.Concat("((", vector_get_ref_alias_c_type);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, "*)({ if (");
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, idx_str_vector_getref_alias);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, " < 0 || ");
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, idx_str_vector_getref_alias);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, " >= ");
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, vec_str_vector_getref_alias);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, vector_get_ref_alias_arrow_or_dot);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, "len) { printf(\"Vector bounds check failed at line %d\\n\", __LINE__); exit(1); } &(");
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, vec_str_vector_getref_alias);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, vector_get_ref_alias_arrow_or_dot);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, "data[");
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, idx_str_vector_getref_alias);
                vector_get_ref_alias_res = std.Concat(vector_get_ref_alias_res, "]); }))");
                return std.Clone(ctx, vector_get_ref_alias_res);
            }

            if std.str_eq(func_str, "os.HashMapNew") || std.str_eq(func_str, "os_HashMapNew") ||
               std.str_eq(func_str, "std.HashMapNew") || std.str_eq(func_str, "std_HashMapNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling HashMapNew FFI override", ctx);
                mut args_vec_hashmap_new: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_hashmap_new[0]);
                mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);

                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_HashMap_int_int", env, ctx
                );

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_str, arena_representation, ctx);

                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .keys = NULL, .values = NULL, .occupied = NULL, .len = 0, .capacity = 0, .arena = ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, " })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.PoolNew") || std.str_eq(func_str, "os_PoolNew") ||
               std.str_eq(func_str, "std.PoolNew") || std.str_eq(func_str, "std_PoolNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling PoolNew FFI override", ctx);
                mut args_vec_pool_new: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_pool_new[0]);
                mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);

                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_Pool_int", env, ctx
                );

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_str, arena_representation, ctx);

                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .arena = ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, ", .capacity = 0, .data = NULL, .free_len = 0, .free_list = NULL, .len = 0, .occupied = NULL })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.MutexNew") || std.str_eq(func_str, "std_MutexNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling MutexNew FFI override", ctx);
                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_Mutex_Any", env, ctx
                );
                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .lock_state = std_Mutex_Alloc() })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.ChannelNew") || std.str_eq(func_str, "std_ChannelNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling ChannelNew FFI override", ctx);
                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_Channel_Any", env, ctx
                );
                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .capacity = std_Channel_Alloc(16, sizeof(*(((struct ");
                res = std.Concat(res, type_str);
                res = std.Concat(res, "*)0)->_phantom))), .len = 0 })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.GraphNew") || std.str_eq(func_str, "os_GraphNew") ||
               std.str_eq(func_str, "std.GraphNew") || std.str_eq(func_str, "std_GraphNew") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling GraphNew FFI override", ctx);
                mut args_vec_graph_new: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_graph_new[0]);
                mut arg_str := codegen_generate_expression(arg0_idx, env, ctx);

                mut type_str := codegen_contextual_constructor_struct_name(
                    expr_idx, "std_Graph_Any", env, ctx
                );

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_str, arena_representation, ctx);

                mut res := std.Concat("((struct ", type_str);
                res = std.Concat(res, "){ .nodes = { .arena = ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, ", .capacity = 0, .data = NULL, .free_len = 0, .free_list = NULL, .len = 0, .occupied = NULL } })");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.Clone") || std.str_eq(func_str, "std_Clone") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.Clone FFI override", ctx);
                mut args_vec_std_clone: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_std_clone[0]);
                mut dest_arg_str := codegen_generate_expression(arg0_idx, env, ctx);
                
                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_std_clone[1]);
                mut src_arg_str := codegen_generate_expression(arg1_idx, env, ctx);
                
                mut dest_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut dest_arena_expr := codegen_emit_argument_representation(dest_arg_str, dest_representation, ctx);
                
                mut dest_base := std.Concat(dest_arg_str, ".BaseAddress");
                if std.str_eq(dest_representation.passing_mode, "direct") == 1 {
                    dest_base = std.Concat(dest_arg_str, "->BaseAddress");
                }
                
                mut struct_name := "Node";
                mut src_brand := "current_ctx";
                mut found := 0;
                
                mut src_type := codegen_get_expression_type(arg1_idx, env, ctx);
                if src_type.tag == 7 { // Index
                    struct_name = codegen_get_erased_struct_name(src_type.Index.struct_name, env, ctx);
                    if src_type.Index.brand != empty[Index[str, ctx]] {
                        src_brand = ctx[src_type.Index.brand];
                        found = 1;
                    }
                }
                
                if found == 1 { 
                    mut src_representation := codegen_plan_brand_argument_representation(src_brand, env, ctx);
                    mut src_is_ptr := std.str_eq(src_representation.passing_mode, "direct");
                    
                    mut src_base := std.Concat(src_brand, ".BaseAddress");
                    if src_is_ptr == 1 {
                        src_base = std.Concat(src_brand, "->BaseAddress");
                    }
                    
                    mut res := std.Concat("({ int _src_idx = ", src_arg_str);
                    res = std.Concat(res, "; int _dest_idx = os_ArenaAlloc(");
                    res = std.Concat(res, dest_arena_expr);
                    res = std.Concat(res, ", sizeof(");
                    res = std.Concat(res, struct_name);
                    res = std.Concat(res, ")); *(struct ");
                    res = std.Concat(res, struct_name);
                    res = std.Concat(res, "*)((char*)");
                    res = std.Concat(res, dest_base);
                    res = std.Concat(
                        res,
                        " + (size_t)(uint32_t)(_dest_idx)) = *(struct "
                    );
                    res = std.Concat(res, struct_name);
                    res = std.Concat(res, "*)((char*)");
                    res = std.Concat(res, src_base);
                    res = std.Concat(
                        res,
                        " + (size_t)(uint32_t)(_src_idx)); _dest_idx; })"
                    );
                    return std.Clone(ctx, res);
                } else {
                    if src_type.tag == 5 { // Str
                        mut res := std.Concat("std_Clone_str(", dest_arena_expr);
                        res = std.Concat(res, ", ");
                        res = std.Concat(res, src_arg_str);
                        res = std.Concat(res, ")");
                        return std.Clone(ctx, res);
                    }
                    return std.Clone(ctx, src_arg_str);
                }
            }

            if std.str_eq(func_str, "std.Spawn") || std.str_eq(func_str, "std_Spawn") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.Spawn FFI override", ctx);
                mut args_vec_std_spawn: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut task_func_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(task_func_expr_idx, args_vec_std_spawn[0]);
                mut raw_func_name := codegen_generate_expression(task_func_expr_idx, env, ctx);
                mut resolved_raw_func_name := typechecker.env_resolve_namespaced_ident(env, raw_func_name, ctx);
                
                mut thread_func_name := "";
                mut i := 0;
                while i < len(resolved_raw_func_name) {
                    mut b := std.str_byte_at(resolved_raw_func_name, i);
                    if b == 46 { // '.'
                        thread_func_name = std.Concat(thread_func_name, "_");
                    } else {
                        mut char_slice := std.str_slice(resolved_raw_func_name, i, i + 1);
                        thread_func_name = std.Concat(thread_func_name, char_slice);
                    }
                    i = i + 1;
                }
                
                mut task_arg_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(task_arg_expr_idx, args_vec_std_spawn[1]);
                mut arg_str := codegen_generate_expression(task_arg_expr_idx, env, ctx);
                
                mut is_ptr := 0;
                mut arg_expr := ctx[task_arg_expr_idx];
                if arg_expr.tag == 6 { // AddressOf
                    is_ptr = 1;
                }
                if arg_expr.tag == 0 { // Identifier
                    is_ptr = codegen_expression_is_arena_ptr(task_arg_expr_idx, env, ctx);
                }
                
                mut cast_expr := "";
                if is_ptr == 1 {
                    cast_expr = std.Concat("(void*)", arg_str);
                } else {
                    cast_expr = std.Concat("(void*)(uintptr_t)", arg_str);
                }
                
                mut res := std.Concat("gust_scheduler_spawn(8388608, (void (*)(void*))", thread_func_name);
                res = std.Concat(res, "_pthread_wrapper, ");
                res = std.Concat(res, cast_expr);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "std.Yield") || std.str_eq(func_str, "std_Yield") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling std.Yield FFI override", ctx);
                return std.Clone(ctx, "gust_yield()");
            }

            if std.str_eq(func_str, "os.Exit") || std.str_eq(func_str, "os_Exit") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.Exit FFI override", ctx);
                mut args_vec_os_exit: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg_idx, args_vec_os_exit[0]);
                mut arg_str := codegen_generate_expression(arg_idx, env, ctx);
                mut res := std.Concat("exit(", arg_str);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.ReadFile") || std.str_eq(func_str, "os_ReadFile") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.ReadFile FFI override", ctx);
                mut args_vec_os_read_file: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_read_file[0]);
                mut arg_arena := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_os_read_file[1]);
                mut arg_path := codegen_generate_expression(arg1_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_arena, arena_representation, ctx);

                mut res := std.Concat("os_ReadFile(", arena_expr);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arg_path);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.WriteFile") || std.str_eq(func_str, "os_WriteFile") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.WriteFile FFI override", ctx);
                mut args_vec_os_write_file: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_write_file[0]);
                mut arg_path := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_os_write_file[1]);
                mut arg_contents := codegen_generate_expression(arg1_idx, env, ctx);

                mut res := std.Concat("os_WriteFile(", arg_path);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arg_contents);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.OpenDir") || std.str_eq(func_str, "os_OpenDir") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.OpenDir FFI override", ctx);
                mut args_vec_os_open_dir: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_open_dir[0]);
                mut arg_arena := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_os_open_dir[1]);
                mut arg_path := codegen_generate_expression(arg1_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_arena, arena_representation, ctx);

                mut res := std.Concat("os_OpenDir(", arena_expr);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arg_path);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.ReadDir") || std.str_eq(func_str, "os_ReadDir") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.ReadDir FFI override", ctx);
                mut args_vec_os_read_dir: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_read_dir[0]);
                mut arg_arena := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_os_read_dir[1]);
                mut arg_dir := codegen_generate_expression(arg1_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_arena, arena_representation, ctx);

                mut res := std.Concat("os_ReadDir(", arena_expr);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arg_dir);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.CloseDir") || std.str_eq(func_str, "os_CloseDir") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.CloseDir FFI override", ctx);
                mut args_vec_os_close_dir: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_close_dir[0]);
                mut arg_dir := codegen_generate_expression(arg0_idx, env, ctx);

                mut res := std.Concat("os_CloseDir(", arg_dir);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.ArenaAlloc") || std.str_eq(func_str, "os_ArenaAlloc") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.ArenaAlloc FFI override", ctx);
                mut args_vec_os_arena_alloc: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_arena_alloc[0]);
                mut arg_arena := codegen_generate_expression(arg0_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_arena, arena_representation, ctx);

                mut struct_name := (*env).current_alloc_struct;
                if std.str_eq(struct_name, "") {
                    struct_name = "SessionNode";
                }
                mut c_size_type_name := codegen_get_c_type_name_by_struct_name(struct_name, ctx);

                mut res := std.Concat("os_ArenaAlloc(", arena_expr);
                res = std.Concat(res, ", sizeof(");
                res = std.Concat(res, c_size_type_name);
                res = std.Concat(res, "))");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.ArenaValidate") || std.str_eq(func_str, "os_ArenaValidate") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.ArenaValidate FFI override", ctx);
                mut args_vec_os_arena_validate: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_arena_validate[0]);
                mut arg_arena := codegen_generate_expression(arg0_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg0_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg_arena, arena_representation, ctx);

                mut res := std.Concat("os_Arena_Validate(", arena_expr);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            if std.str_eq(func_str, "os.path_join") || std.str_eq(func_str, "os_path_join") {
                codegen_log_trace("👁️", "codegen_generate_expression: transpiling os.path_join FFI override", ctx);
                mut args_vec_os_path_join: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg0_idx, args_vec_os_path_join[0]);
                mut arg0 := codegen_generate_expression(arg0_idx, env, ctx);

                mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg1_idx, args_vec_os_path_join[1]);
                mut arg1 := codegen_generate_expression(arg1_idx, env, ctx);

                mut arg2_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(arg2_idx, args_vec_os_path_join[2]);
                mut arg2 := codegen_generate_expression(arg2_idx, env, ctx);

                mut arena_representation := codegen_plan_argument_representation(arg2_idx, env, ctx);
                mut arena_expr := codegen_emit_argument_representation(arg2, arena_representation, ctx);

                mut res := std.Concat("os_path_join(", arg0);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arg1);
                res = std.Concat(res, ", ");
                res = std.Concat(res, arena_expr);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);
            }

            mut resolved_func := typechecker.env_resolve_namespaced_ident(env, func_str, ctx);
            mut resolved_sig := (*env).function_registry.Get(resolved_func);
            if resolved_sig.Ok {
                if resolved_sig.Val.is_extern == 1 &&
                   len(resolved_sig.Val.extern_symbol_name) > 0
                {
                    resolved_func = std.Clone(
                        ctx,
                        resolved_sig.Val.extern_symbol_name
                    );
                }
            }
            mut c_func := "";
            mut i := 0;
            while i < len(resolved_func) {
                mut b := std.str_byte_at(resolved_func, i);
                if b == 46 { // '.'
                    c_func = std.Concat(c_func, "_");
                } else {
                    mut char_slice := std.str_slice(resolved_func, i, i + 1);
                    c_func = std.Concat(c_func, char_slice);
                }
                i = i + 1;
            }

                 mut args_vec_generic_call_tail: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[expr_idx].Call.arguments];
                mut args_str := "";
                mut j := 0;
                while j < len(args_vec_generic_call_tail) {
                    if j > 0 {
                        args_str = std.Concat(args_str, ", ");
                    }
                    mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx.Set(arg_idx, args_vec_generic_call_tail[j]);
                    mut arg_str := codegen_generate_expression(arg_idx, env, ctx);

                    mut arg_source_type := codegen_get_expression_type(arg_idx, env, ctx);
                    mut arg_type := typechecker.env_resolve_type(env, arg_source_type, ctx);
                    mut value_class := "value";
                    if typechecker.typechecker_classify_resolved_type(arg_type, typechecker.typechecker_classification_arena(), env, ctx) == 1 { value_class = "arena"; }
                    mut arg_representation := codegen_plan_argument_representation_for_value_class(arg_source_type, value_class, env, ctx);
                    arg_str = codegen_emit_argument_representation(arg_str, arg_representation, ctx);

                    args_str = std.Concat(args_str, arg_str);
                    j = j + 1;
                }
                mut res := std.Concat(c_func, "(");
                res = std.Concat(res, args_str);
                res = std.Concat(res, ")");
                return std.Clone(ctx, res);

        }
        if tag == 13 { // Empty
            mut t_empty := ctx[ctx[expr_idx].Empty.target_type];
            mut resolved_t := typechecker.env_resolve_type(env, t_empty, ctx);
            return std.Clone(ctx, codegen_gen_type_aware_initializer(resolved_t, env, ctx));
        }
        if tag == 14 { // Query (Phase 21.3 semantic no-op)
            return codegen_generate_expression(
                ctx[expr_idx].Query.terminal, env, ctx
            );
        }
    }
    return "0";
}

func codegen_resource_cleanup_c_function_name(destructor_name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut resolved := typechecker.env_resolve_namespaced_ident(env, destructor_name, ctx);
        mut sig := (*env).function_registry.Get(resolved);
        if sig.Ok {
            if sig.Val.is_extern == 1 && len(sig.Val.extern_symbol_name) > 0 {
                resolved = std.Clone(ctx, sig.Val.extern_symbol_name);
            }
        }
        mut c_name := "";
        mut i := 0;
        while i < len(resolved) {
            if std.str_byte_at(resolved, i) == 46 { // '.'
                c_name = std.Concat(c_name, "_");
            } else {
                c_name = std.Concat(c_name, std.str_slice(resolved, i, i + 1));
            }
            i = i + 1;
        }
        return std.Clone(ctx, c_name);
    }
}

func codegen_generate_resource_cleanup_plan(kind: str, span: token.Span, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut key := typechecker.resource_cleanup_plan_key(
            env as *typechecker.TypeEnvironment[ctx], kind, span, ctx
        );
        guard plan_lookup := (*env).resource_cleanup_plans.Get(key) else {
            return "";
        };
        mut actions: std.Vector[typechecker.ResourceCleanupAction[ctx], ctx] := ctx[plan_lookup];
        mut generated := "";
        mut i := 0;
        while i < len(actions) {
            mut action := actions[i];
            mut line := "    ";
            if len(action.cleanup_condition) > 0 {
                line = std.Concat(line, "if (");
                line = std.Concat(line, action.cleanup_condition);
                line = std.Concat(line, ") { ");
            }
            line = std.Concat(
                line,
                codegen_resource_cleanup_c_function_name(
                    action.destructor_name, env, ctx
                )
            );
            line = std.Concat(line, "(");
            line = std.Concat(line, action.storage_name);
            line = std.Concat(line, ");");
            if len(action.cleanup_condition) > 0 {
                line = std.Concat(line, " }");
            }
            line = std.Concat(line, "\n");
            generated = std.Concat(generated, line);
            i = i + 1;
        }
        return std.Clone(ctx, generated);
    }
}

func codegen_generate_active_defers(env: &typechecker.TypeEnvironment[ctx], start_index: int, ctx: &Arena) str {
    unsafe {
        mut generated := "";
        mut i := len((*env).codegen_active_defers) - 1;
        while i >= start_index {
            mut entry := (*env).codegen_active_defers[i];
            if len(entry) > 0 && std.str_byte_at(entry, 0) == 68 {
                generated = std.Concat(
                    generated, std.str_slice(entry, 1, len(entry))
                );
            }
            i = i - 1;
        }
        return std.Clone(ctx, generated);
    }
}

func codegen_generate_active_scope_exits(env: &typechecker.TypeEnvironment[ctx], start_index: int, stop_at_loop: int, ctx: &Arena) str {
    unsafe {
        mut generated := "";
        mut i := len((*env).codegen_active_defers) - 1;
        while i >= start_index {
            mut entry := (*env).codegen_active_defers[i];
            if len(entry) == 0 && stop_at_loop == 1 {
                return std.Clone(ctx, generated);
            }
            if len(entry) > 0 {
                mut output := entry;
                if std.str_byte_at(entry, 0) == 68 {
                    output = std.str_slice(entry, 1, len(entry));
                }
                generated = std.Concat(
                    generated, output
                );
            }
            i = i - 1;
        }
        return std.Clone(ctx, generated);
    }
}

func codegen_generate_block_statement(block_idx: Index[ast.BlockStatement[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str { 
    unsafe {
        if block_idx == empty[Index[ast.BlockStatement[ctx], ctx]] {
            return "";
        }
        mut block_val_codegen_block := ctx[block_idx];
        mut body_statements_codegen_block: std.Vector[ast.Statement[ctx], ctx] := ctx[block_val_codegen_block.statements];
        mut chunks: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut defer_start := len((*env).codegen_active_defers);
        mut cleanup := codegen_generate_resource_cleanup_plan(
            "block", block_val_codegen_block.span, env, ctx
        );
        if len(cleanup) > 0 {
            (*env).codegen_active_defers.Push(cleanup);
        }
        mut j := 0;
        while j < len(body_statements_codegen_block) {
            mut child_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx.Set(child_stmt_idx, body_statements_codegen_block[j]);
            
            mut stmt_tag := ctx[child_stmt_idx].tag;
            if stmt_tag == 11 { // Defer
                mut defer_expr_idx := ctx[child_stmt_idx].Defer.expr;
                mut expr_str := codegen_generate_expression(defer_expr_idx, env, ctx);
                mut formatted := std.Concat("D    ", expr_str);
                formatted = std.Concat(formatted, ";\n");
                (*env).codegen_active_defers.Push(std.Clone(ctx, formatted));
            } else {
                mut child_c := codegen_generate_statement(child_stmt_idx, env, ctx);
                chunks.Push(child_c);
            }
            j = j + 1;
        }
        mut local_defers := codegen_generate_active_scope_exits(
            env, defer_start, 0, ctx
        );
        if len(local_defers) > 0 {
            chunks.Push(local_defers);
        }
        while len((*env).codegen_active_defers) > defer_start {
            (*env).codegen_active_defers.Pop();
        }
        mut generated := codegen_join_chunks(chunks, ctx);
        return std.Clone(ctx, generated);
    }
}

func codegen_generate_statement(stmt_idx: Index[ast.Statement[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return "";
        }
        mut tag := ctx[stmt_idx].tag;
        if tag == 4 { // VarDecl
                    mut t_var: ast.Type[ctx];
                    mut span := ctx[stmt_idx].VarDecl.span;
                    mut prefix := typechecker.typechecker_resolution_scope_key(env as *typechecker.TypeEnvironment[ctx], ctx);
                    
                    mut found_idx := 0 - 1;
                    mut i := 0;
                    while i < len((*env).resolved_types_nested) {
                        mut entry := (*env).resolved_types_nested[i];
                        if std.str_eq(entry.prefix, prefix) {
                            found_idx = i;
                            i = len((*env).resolved_types_nested);
                        }
                        i = i + 1;
                    }
                    
                    mut found := 0;
                    if found_idx != 0 - 1 { 
                        mut entry_ref := &(*env).resolved_types_nested[found_idx];
                        mut j := 0;
                        while j < len((*entry_ref).types) {
                            mut t_entry := (*entry_ref).types[j];
                            if t_entry.start_offset == span.start.offset && t_entry.end_offset == span.end.offset {
                                t_var = t_entry.val_type;
                                found = 1;
                                j = len((*entry_ref).types);
                            }
                            j = j + 1;
                        }
                    }
                    if found == 0 {
                        t_var.tag = 3; // Void
                    }
                    mut c_type := codegen_get_c_type(t_var, env, ctx);
                    
                    mut struct_name := "";
                    if t_var.tag == 8 { // Struct
                        struct_name = codegen_get_erased_struct_name(t_var.Struct.struct_name, env, ctx);
                    } else {
                        if t_var.tag == 7 { // Index
                            struct_name = codegen_get_erased_struct_name(t_var.Index.struct_name, env, ctx);
                        }
                    }
                    (*env).current_alloc_struct = struct_name;

            mut init_val := "";
            if ctx[stmt_idx].VarDecl.value != empty[Index[ast.Expression[ctx], ctx]] {
                init_val = codegen_generate_expression(ctx[stmt_idx].VarDecl.value, env, ctx);
            } else { 
                init_val = codegen_gen_type_aware_initializer(t_var, env, ctx);
            }
            (*env).current_alloc_struct = "";

            mut res := std.Concat("    ", c_type);
            res = std.Concat(res, " ");
            res = std.Concat(res, ctx[stmt_idx].VarDecl.name);
            res = std.Concat(res, " = ");
            res = std.Concat(res, init_val);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if tag == 5 { // Assignment
            mut lhs_type := codegen_get_expression_type(ctx[stmt_idx].Assignment.left, env, ctx);
            mut struct_name := "";
            if lhs_type.tag == 8 { // Struct
                struct_name = codegen_get_erased_struct_name(lhs_type.Struct.struct_name, env, ctx);
            } else {
                if lhs_type.tag == 7 { // Index
                    struct_name = codegen_get_erased_struct_name(lhs_type.Index.struct_name, env, ctx);
                }
            }
            (*env).current_alloc_struct = struct_name;

            mut left_str := codegen_generate_expression(ctx[stmt_idx].Assignment.left, env, ctx);
            mut val_str := codegen_generate_expression(ctx[stmt_idx].Assignment.value, env, ctx);
            
            (*env).current_alloc_struct = "";

            mut res := std.Concat("    ", left_str);
            res = std.Concat(res, " = ");
            res = std.Concat(res, val_str);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if tag == 12 { // Return
            mut expr_str := "";
            mut res := "";
            mut active_defers := codegen_generate_active_defers(env, 0, ctx);
            mut resource_cleanup := codegen_generate_resource_cleanup_plan(
                "return", ctx[stmt_idx].Return.span, env, ctx
            );
            if ctx[stmt_idx].Return.expr != empty[Index[ast.Expression[ctx], ctx]] {
                expr_str = codegen_generate_expression(ctx[stmt_idx].Return.expr, env, ctx);
                if len(active_defers) > 0 || len(resource_cleanup) > 0 {
                    mut return_type := codegen_get_expression_type(
                        ctx[stmt_idx].Return.expr, env, ctx
                    );
                    mut return_c_type := codegen_get_c_type(return_type, env, ctx);
                    mut return_temp := std.Concat(
                        "_gust_return_",
                        std.FormatInt(ctx[stmt_idx].Return.span.start.line)
                    );
                    return_temp = std.Concat(return_temp, "_");
                    return_temp = std.Concat(
                        return_temp,
                        std.FormatInt(ctx[stmt_idx].Return.span.start.column)
                    );
                    res = std.Concat("    ", return_c_type);
                    res = std.Concat(res, " ");
                    res = std.Concat(res, return_temp);
                    res = std.Concat(res, " = ");
                    res = std.Concat(res, expr_str);
                    res = std.Concat(res, ";\n");
                    expr_str = return_temp;
                }
            }
            res = std.Concat(res, active_defers);
            res = std.Concat(res, resource_cleanup);
            res = std.Concat(res, "    return ");
            res = std.Concat(res, expr_str);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if tag == 13 { // Expression
            mut expression_idx := ctx[stmt_idx].Expression.expr;
            mut expression := ctx[expression_idx];
            mut expression_text := codegen_generate_expression(
                expression_idx, env, ctx
            );
            mut res := "";
            if expression.tag == 0 &&
               (std.str_eq(expression.Identifier.name, "break") == 1 ||
                std.str_eq(expression.Identifier.name, "continue") == 1) &&
               len((*env).codegen_active_defers) > 0 {
                res = codegen_generate_active_scope_exits(
                    env, 0, 1, ctx
                );
            }
            res = std.Concat(res, "    ");
            res = std.Concat(res, expression_text);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if tag == 3 { // FunctionDecl
            mut f_name := ctx[stmt_idx].FunctionDecl.name;
            mut namespaced_name := typechecker.env_resolve_namespaced_ident(env, f_name, ctx);
            if typechecker.typechecker_is_protected_resource_derived(
                (*env).current_function_identity_scope,
                env as *typechecker.TypeEnvironment[ctx],
                ctx
            ) == 1 {
                namespaced_name = std.Clone(ctx, (*env).current_function_identity_scope);
            }
            mut sig_lookup := (*env).function_registry.Get(namespaced_name);
            mut t_ret := ctx[ctx[stmt_idx].FunctionDecl.return_type];
            if sig_lookup.Ok {
                t_ret = sig_lookup.Val.return_type;
            }

            // Extern functions are declarations owned by the host linker.
            // Their forward declaration uses the declared external symbol;
            // never synthesize an empty Gust function body for them.
            if ctx[stmt_idx].FunctionDecl.is_extern == 1 {
                return std.Clone(ctx, "");
            }

            if std.str_eq(namespaced_name, "main") == 1 {
                (*env).current_params.Clear();
                mut resolved_main_return := typechecker.env_resolve_type(env, t_ret, ctx);
                mut body_idx := ctx[stmt_idx].FunctionDecl.body;
                mut body_c := codegen_generate_block_statement(body_idx, env, ctx);
                mut res := "";

                if resolved_main_return.tag == 0 ||
                   resolved_main_return.tag == 1 ||
                   resolved_main_return.tag == 2
                {
                    mut main_return_c_type := codegen_get_c_type(
                        resolved_main_return,
                        env,
                        ctx
                    );
                    res = std.Concat(res, "static int gust_user_exit_status = 0;\n\n");
                    res = std.Concat(res, main_return_c_type);
                    res = std.Concat(res, " gust_user_main_impl(void* _gust_arg) {\n");
                    res = std.Concat(res, body_c);
                    res = std.Concat(res, "}\n\n");
                    res = std.Concat(res, "void gust_user_main(void* _gust_arg) {\n");
                    res = std.Concat(
                        res,
                        "    gust_user_exit_status = (int)gust_user_main_impl(_gust_arg);\n"
                    );
                    res = std.Concat(res, "}\n\n");
                } else {
                    res = std.Concat(res, "void gust_user_main(void* _gust_arg) {\n");
                    res = std.Concat(res, body_c);
                    res = std.Concat(res, "}\n\n");
                }

                res = std.Concat(res, "int main(int argc, char** argv) {\n");
                res = std.Concat(res, "    os_argc = argc;\n");
                res = std.Concat(res, "    os_argv = argv;\n");
                res = std.Concat(res, "    gust_scheduler_init(get_num_threads_to_use());\n");
                res = std.Concat(res, "    gust_scheduler_spawn(8388608, gust_user_main, NULL);\n");
                res = std.Concat(res, "    gust_scheduler_destroy();\n");
                if resolved_main_return.tag == 0 ||
                   resolved_main_return.tag == 1 ||
                   resolved_main_return.tag == 2
                {
                    res = std.Concat(res, "    return gust_user_exit_status;\n");
                } else {
                    res = std.Concat(res, "    return 0;\n");
                }
                res = std.Concat(res, "}\n\n");
                return std.Clone(ctx, res);
            }

            mut c_ret := codegen_get_c_type(t_ret, env, ctx);
            mut res := std.Concat(c_ret, " ");

            mut c_func_name := "";
            mut char_idx := 0;
            while char_idx < len(namespaced_name) {
                mut b := std.str_byte_at(namespaced_name, char_idx);
                if b == 46 { // '.'
                    c_func_name = std.Concat(c_func_name, "_");
                } else {
                    c_func_name = std.Concat(c_func_name, std.str_slice(namespaced_name, char_idx, char_idx + 1));
                }
                char_idx = char_idx + 1;
            }
            res = std.Concat(res, c_func_name);
            res = std.Concat(res, "(");

            mut params_vec_function_emit: std.Vector[ast.Parameter[ctx], ctx] := ctx[ctx[stmt_idx].FunctionDecl.params];
            
            (*env).current_params.Clear();
            mut params_str := "";
            mut i := 0;
            while i < len(params_vec_function_emit) { 
                if i > 0 {
                    params_str = std.Concat(params_str, ", ");
                }
                mut p := params_vec_function_emit[i];
                (*env).current_params.Push(p.name);
                mut p_type := p.param_type;
                if sig_lookup.Ok { 
                    p_type = sig_lookup.Val.params[i];
                }
                mut p_c_type := codegen_get_c_type(p_type, env, ctx);
                mut p_decl := std.Concat(p_c_type, " ");
                p_decl = std.Concat(p_decl, p.name);
                params_str = std.Concat(params_str, p_decl);
                i = i + 1;
            }
            res = std.Concat(res, params_str);
            res = std.Concat(res, ") {\n");

            mut body_idx := ctx[stmt_idx].FunctionDecl.body;
            mut body_c := codegen_generate_block_statement(body_idx, env, ctx);
            
            mut is_recursive := codegen_is_function_recursive(body_idx, f_name, ctx);
            if is_recursive == 1 {
                mut check_str := "    if (GUST_UNLIKELY(--gust_loop_ticks <= 0)) { gust_loop_ticks = GUST_TICK_INTERVAL; gust_yield(); }\n";
                body_c = std.Concat(check_str, body_c);
            }
            
            res = std.Concat(res, body_c);
            res = std.Concat(res, "}\n\n");


  if len(params_vec_function_emit) == 1 {
                    codegen_log_trace("👁", std.Format("codegen_generate_statement: generating pthread_wrapper for %s", namespaced_name), ctx);
                    mut param := params_vec_function_emit[0];
                    mut wrapper_p_type := param.param_type;
                    if sig_lookup.Ok {
                        wrapper_p_type = sig_lookup.Val.params[0];
                    }
                    mut wrapper_p_c_type := codegen_get_c_type(wrapper_p_type, env, ctx);

                    mut is_ptr := 0;
                    if wrapper_p_type.tag == 9 { // RawPointer
                        is_ptr = 1;
                    }

                    mut is_struct := 0;
                    if wrapper_p_type.tag == 8 || wrapper_p_type.tag == 10 || wrapper_p_type.tag == 6 || wrapper_p_type.tag == 5 {
                        is_struct = 1;
                    }

                    mut cast_str := "";
                    if is_ptr == 1 {
                        cast_str = std.Concat("(", wrapper_p_c_type);
                        cast_str = std.Concat(cast_str, ")arg");
                    } else {
                        if is_struct == 1 {
                            cast_str = std.Concat("*(", wrapper_p_c_type);
                            cast_str = std.Concat(cast_str, "*)arg");
                        } else {
                            cast_str = std.Concat("(", wrapper_p_c_type);
                            cast_str = std.Concat(cast_str, ")(uintptr_t)arg");
                        }
                    }

                    mut wrapper_decl := std.Concat("void* ", c_func_name);
                    wrapper_decl = std.Concat(wrapper_decl, "_pthread_wrapper(void* arg) {\n");

                    mut wrapper_call := std.Concat("    ", c_func_name);
                    wrapper_call = std.Concat(wrapper_call, "(");
                    wrapper_call = std.Concat(wrapper_call, cast_str);
                    wrapper_call = std.Concat(wrapper_call, ");\n");

                    wrapper_decl = std.Concat(wrapper_decl, wrapper_call);
                    wrapper_decl = std.Concat(wrapper_decl, "    return NULL;\n}\n\n");

                    res = std.Concat(res, wrapper_decl);
                }

                return std.Clone(ctx, res);
            }
            if tag == 9 { // Guard
                mut name := ctx[stmt_idx].Guard.name;
                mut value := ctx[stmt_idx].Guard.value;
                mut else_body := ctx[stmt_idx].Guard.else_body;
                mut span := ctx[stmt_idx].Guard.span;

                mut rhs_type := codegen_get_expression_type(value, env, ctx);
                mut wrapper_c_type := codegen_get_c_type(rhs_type, env, ctx);

                // Derive the bound value type from this guard's wrapper. The
                // environment's variable map is keyed only by identifier, so
                // an unrelated binding with the same name can overwrite it
                // before code generation starts.
                mut var_c_type := "unknown";
                mut resolved_rhs_type := typechecker.env_resolve_type(env, rhs_type, ctx);
                if resolved_rhs_type.tag == 8 { // Struct
                    mut layout_lookup := (*env).struct_registry.get_opt(resolved_rhs_type.Struct.struct_name);
                    match layout_lookup {
                        Some { val } => {
                            mut val_type_lookup := (*val).fields.get_opt("Val");
                            match val_type_lookup {
                                Some { val } => {
                                    var_c_type = codegen_get_c_type(*val, env, ctx);
                                }
                                None => {
                                }
                            }
                        }
                        None => {
                        }
                    }
                }

                mut line_str := std.FormatInt(span.start.line);
                mut col_str := std.FormatInt(span.start.column);
                mut temp_name := std.Concat("_guard_res_", name);
                temp_name = std.Concat(temp_name, "_");
                temp_name = std.Concat(temp_name, line_str);
                temp_name = std.Concat(temp_name, "_");
                temp_name = std.Concat(temp_name, col_str);

                mut val_expr_str := codegen_generate_expression(value, env, ctx);

                // Guard else is a real lexical block: it must share the same
                // defer and compiler-cleanup machinery as if/while/match.
                mut else_c := codegen_generate_block_statement(
                    else_body, env, ctx
                );
                else_c = std.Concat("    ", else_c);

                mut res := std.Concat("    ", wrapper_c_type);
                res = std.Concat(res, " ");
                res = std.Concat(res, temp_name);
                res = std.Concat(res, " = {0};\n");

                res = std.Concat(res, "    ");
                res = std.Concat(res, temp_name);
                res = std.Concat(res, " = ");
                res = std.Concat(res, val_expr_str);
                res = std.Concat(res, ";\n");

                res = std.Concat(res, "    if (!");
                res = std.Concat(res, temp_name);
                res = std.Concat(res, ".Ok) {\n");
                res = std.Concat(res, else_c);
                res = std.Concat(res, "    }\n");

                res = std.Concat(res, "    ");
                res = std.Concat(res, var_c_type);
                res = std.Concat(res, " ");
                res = std.Concat(res, name);
                res = std.Concat(res, " = ");
                res = std.Concat(res, temp_name);
                res = std.Concat(res, ".Val;\n");

                return std.Clone(ctx, res);
            }
            if tag == 10 { // UnsafeBlock
                mut body_idx := ctx[stmt_idx].UnsafeBlock.body;
                mut body_c := codegen_generate_block_statement(body_idx, env, ctx);
                mut res := "    {\n";
                res = std.Concat(res, body_c);
                res = std.Concat(res, "    }\n");
                return std.Clone(ctx, res);
            }
            if tag == 6 { // While
                mut cond_str := codegen_generate_expression(ctx[stmt_idx].While.condition, env, ctx);
                (*env).codegen_active_defers.Push("");
                mut body_str := codegen_generate_block_statement(ctx[stmt_idx].While.body, env, ctx);
                (*env).codegen_active_defers.Pop();
                
                mut check_str := "        if (GUST_UNLIKELY(--gust_loop_ticks <= 0)) { gust_loop_ticks = GUST_TICK_INTERVAL; gust_yield(); }\n";
                body_str = std.Concat(check_str, body_str);
                
                mut res := std.Concat("    while (", cond_str);
                res = std.Concat(res, ") {\n");
                res = std.Concat(res, body_str);
                res = std.Concat(res, "    }\n");
                return std.Clone(ctx, res);
            }
            if tag == 7 { // If
                mut cond_str := codegen_generate_expression(ctx[stmt_idx].If.condition, env, ctx);
                mut cons_str := codegen_generate_block_statement(ctx[stmt_idx].If.consequence, env, ctx);
                if ctx[stmt_idx].If.alternative == empty[Index[ast.BlockStatement[ctx], ctx]] {
                    mut res := std.Concat("    if (", cond_str);
                    res = std.Concat(res, ") {\n");
                    res = std.Concat(res, cons_str);
                    res = std.Concat(res, "    }\n");
                    return std.Clone(ctx, res);
                } else {
                    mut alt_str := codegen_generate_block_statement(ctx[stmt_idx].If.alternative, env, ctx);
                    mut res := std.Concat("    if (", cond_str);
                    res = std.Concat(res, ") {\n");
                    res = std.Concat(res, cons_str);
                    res = std.Concat(res, "    } else {\n");
                    res = std.Concat(res, alt_str);
                    res = std.Concat(res, "    }\n");
                    return std.Clone(ctx, res);
                }
            }
        if tag == 8 { // Match
            mut expr_idx := ctx[stmt_idx].Match.expression;
            mut expr_str := codegen_generate_expression(expr_idx, env, ctx);
            mut expr_t := codegen_get_expression_type(expr_idx, env, ctx);
            mut resolved_expr_t := typechecker.env_resolve_type(env, expr_t, ctx);

            mut enum_name := "Shape";
            if resolved_expr_t.tag == 8 { // Struct
                enum_name = resolved_expr_t.Struct.struct_name;
            } else if resolved_expr_t.tag == 11 { // Reference
                mut inner_t := ctx[resolved_expr_t.Reference.inner];
                if inner_t.tag == 8 {
                    enum_name = inner_t.Struct.struct_name;
                }
            } else if resolved_expr_t.tag == 9 { // RawPointer
                mut inner_t := ctx[resolved_expr_t.RawPointer.inner];
                if inner_t.tag == 8 {
                    enum_name = inner_t.Struct.struct_name;
                }
            }
            mut erased_enum_name := codegen_get_erased_struct_name(enum_name, env, ctx);

            mut arrow_or_dot := ".";
            if expr_t.tag == 9 || expr_t.tag == 11 {
                arrow_or_dot = "->";
            }

            mut parent_brand := empty[Index[str, ctx]];
            mut curr_t := resolved_expr_t;
            while curr_t.tag == 9 || curr_t.tag == 11 {
                if curr_t.tag == 9 {
                    curr_t = ctx[curr_t.RawPointer.inner];
                } else {
                    curr_t = ctx[curr_t.Reference.inner];
                }
            }
            if curr_t.tag == 8 {
                parent_brand = curr_t.Struct.brand;
            }

            mut res := std.Concat("    switch (", expr_str);
            res = std.Concat(res, arrow_or_dot);
            res = std.Concat(res, "tag) {
");

            mut cases_vec_match_emit: std.Vector[ast.MatchCase[ctx], ctx] := ctx[ctx[stmt_idx].Match.cases];
            mut i := 0;
            while i < len(cases_vec_match_emit) {
                mut case_val := cases_vec_match_emit[i];
                mut tag_name := std.Concat(erased_enum_name, "_Tag__");
                tag_name = std.Concat(tag_name, case_val.variant_name);

                res = std.Concat(res, "        case ");
                res = std.Concat(res, tag_name);
                res = std.Concat(res, ": {
");

                mut variant_struct_name := std.Concat(enum_name, "_");
                variant_struct_name = std.Concat(variant_struct_name, case_val.variant_name);
                mut layout_lookup := (*env).struct_registry.Get(variant_struct_name);

                if layout_lookup.Ok == false {
                    mut erased_variant_struct_name := std.Concat(erased_enum_name, "_");
                    erased_variant_struct_name = std.Concat(erased_variant_struct_name, case_val.variant_name);
                    layout_lookup = (*env).struct_registry.Get(erased_variant_struct_name);
                }

                if layout_lookup.Ok == false {
                    mut enum_layout_lookup := (*env).struct_registry.Get(enum_name);
                    if enum_layout_lookup.Ok {
                        mut variant_type_lookup := enum_layout_lookup.Val.fields.Get(case_val.variant_name);
                        if variant_type_lookup.Ok {
                            mut variant_type := variant_type_lookup.Val;
                            if variant_type.tag == 8 {
                                layout_lookup = (*env).struct_registry.Get(variant_type.Struct.struct_name);
                            }
                        }
                    }
                }

                if layout_lookup.Ok {
                    mut fields_vec_match_emit: std.Vector[str, ctx] := ctx[case_val.fields];
                    mut f_idx := 0;
                    while f_idx < len(fields_vec_match_emit) {
                        mut field_name := fields_vec_match_emit[f_idx];
                        mut f_type_lookup := layout_lookup.Val.fields.Get(field_name);
                        if f_type_lookup.Ok {
                            mut ref_t: ast.Type[ctx];
                            ref_t.tag = 11; // Reference
                            ref_t.Reference.inner = os.ArenaAlloc(ctx);
                            ctx.Set(ref_t.Reference.inner, f_type_lookup.Val);
                            ref_t.Reference.brand = parent_brand;

                            mut field_c_type := codegen_get_c_type(ref_t, env, ctx);
                            mut bind_line := std.Concat("            ", field_c_type);
                            bind_line = std.Concat(bind_line, " ");
                            bind_line = std.Concat(bind_line, field_name);
                            bind_line = std.Concat(bind_line, " = &(");
                            bind_line = std.Concat(bind_line, expr_str);
                            bind_line = std.Concat(bind_line, arrow_or_dot);
                            bind_line = std.Concat(bind_line, case_val.variant_name);
                            bind_line = std.Concat(bind_line, ".");
                            bind_line = std.Concat(bind_line, field_name);
                            bind_line = std.Concat(bind_line, ");\n");
                            res = std.Concat(res, bind_line);
                        }
                        f_idx = f_idx + 1;
                    }
                }                    
                mut body_str := codegen_generate_block_statement(case_val.body, env, ctx);
                res = std.Concat(res, body_str);
                
                res = std.Concat(res, "            break;\n        }\n");
                i = i + 1;
            }
            res = std.Concat(res, "    }\n");
            return std.Clone(ctx, res);
        }
            if tag == 11 { // Defer
                return "";
            }
        }
        return "";
    }


func codegen_sort_variants(variants: std.Vector[str, ctx], ctx: &Arena) std.Vector[str, ctx] {
    mut sorted: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut i := 0;
    while i < len(variants) {
        sorted.Push(std.Clone(ctx, variants[i]));
        i = i + 1;
    }
    mut n := len(sorted);
    mut x := 0;
    while x < n {
        mut y := x + 1;
        while y < n {
            mut cmp := typechecker.typechecker_str_compare(sorted[x], sorted[y]);
            if cmp > 0 {
                mut temp := sorted[x];
                sorted.Set(x, sorted[y]);
                sorted.Set(y, temp);
            }
            y = y + 1;
        }
        x = x + 1;
    }
    return sorted;
}

func codegen_has_thread_local_context(env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        mut keys := (*env).struct_registry.Keys(ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            if std.str_find(key, "ThreadLocalContext") != 0 - 1 {
                return 1;
            }
            i = i + 1;
        }
    }
    return 0;
}


func codegen_generate_clone_helper(struct_name: str, env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut res := std.Concat('int std_GenerationalArena_Clone_', struct_name);
        res = std.Concat(res, '(os_Arena* dest, os_Arena* src, int src_idx) {\n');
        res = std.Concat(res, '    if (src_idx == 0xFFFFFFFF) return 0xFFFFFFFF;\n');
        res = std.Concat(res, '    int dest_idx = os_ArenaAlloc(dest, sizeof(struct ');
        res = std.Concat(res, struct_name);
        res = std.Concat(res, '));\n');
        
        res = std.Concat(res, '    struct ');
        res = std.Concat(res, struct_name);
        res = std.Concat(res, '* src_ptr = (struct ');
        res = std.Concat(res, struct_name);
        res = std.Concat(
            res,
            '*)((char*)src->BaseAddress + (size_t)(uint32_t)(src_idx));\n'
        );
        
        res = std.Concat(res, '    struct ');
        res = std.Concat(res, struct_name);
        res = std.Concat(res, '* dest_ptr = (struct ');
        res = std.Concat(res, struct_name);
        res = std.Concat(
            res,
            '*)((char*)dest->BaseAddress + (size_t)(uint32_t)(dest_idx));\n'
        );
        res = std.Concat(res, '    *dest_ptr = *src_ptr;\n');

        mut orig_name := codegen_find_original_struct_name(struct_name, env, ctx);
        mut lookup_struct := (*env).struct_registry.get_opt(orig_name);
        match lookup_struct {
            Some { val } => {
                mut layout := *val;
                mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                mut f_idx := 0;
                while f_idx < len(f_keys) {
                    mut f_key := f_keys[f_idx];
                    mut f_type_lookup := layout.fields.get_opt(f_key);
                    match f_type_lookup {
                        Some { val } => {
                            mut f_type := *val;
                            if f_type.tag == 7 { // Index
                                mut nested_struct := f_type.Index.struct_name;
                                mut clean_nested := nested_struct;
                                if std.str_eq(nested_struct, 'Any') == 1 {
                                    clean_nested = 'SessionNode';
                                }
                                mut line := std.Concat('    dest_ptr->', f_key);
                                line = std.Concat(line, ' = std_GenerationalArena_Clone_');
                                line = std.Concat(line, clean_nested);
                                line = std.Concat(line, '(dest, src, src_ptr->');
                                line = std.Concat(line, f_key);
                                line = std.Concat(line, ');\n');
                                res = std.Concat(res, line);
                            }
                        }
                        None => {
                        }
                    }
                    f_idx = f_idx + 1;
                }
            }
            None => {
            }
        }

        res = std.Concat(res, '    return dest_idx;\n');
        res = std.Concat(res, '}\n\n');

        res = std.Concat(res, 'void std_GenerationalArena_Step_');
        res = std.Concat(res, struct_name);
        res = std.Concat(res, '(void* arena_ptr) {\n');
        res = std.Concat(res, '    struct std_GenerationalArena_Generic* arena = (struct std_GenerationalArena_Generic*)arena_ptr;\n');
        res = std.Concat(res, '    if (arena->survivor != 0xFFFFFFFF) {\n');
        res = std.Concat(res, '        arena->survivor = std_GenerationalArena_Clone_');
        res = std.Concat(res, struct_name);
        res = std.Concat(res, '(&arena->next_ctx, &arena->current_ctx, arena->survivor);\n');
        res = std.Concat(res, '    }\n');
        res = std.Concat(res, '    std_GenerationalSwap(&arena->current_ctx, &arena->next_ctx);\n');
        res = std.Concat(res, '}\n\n');

        return std.Clone(ctx, res);
    }
}

func codegen_generate(programs: std.Vector[ast.Program[ctx], ctx], prefixes: std.Vector[str, ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        codegen_log_trace("⚙️", "codegen_generate: commencing code generation pass", ctx);
        mut chunks: std.Vector[str, ctx] := std.VectorNew(ctx);
        chunks.Push("// Transpiled C Code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

typedef void Any;

");

        // 1. Generate Slice structure definitions
        chunks.Push("/* Builtin slice structs are runtime-owned in src/runtime/core_headers.h. */\n\n");

        // 2. Generate forward declarations for all structs
        chunks.Push("// Forward Declarations\n");
        mut struct_keys := codegen_get_topologically_sorted_structs(env, ctx);
        
        mut erased_struct_keys: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut seen_structs: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
        mut erased_to_original: std.HashMap[str, str, ctx] := std.HashMapNew(ctx); 
        
        mut i_erase := 0; 
        while i_erase < len(struct_keys) {
            mut key := struct_keys[i_erase];
            mut erased_name := codegen_get_erased_struct_name(key, env, ctx);
            mut has_seen := 0;
            mut seen_lookup := seen_structs.get_opt(erased_name);
            match seen_lookup {
                Some { val } => {
                    has_seen = 1;
                }
                None => {
                }
            }
            if has_seen == 0 {
                erased_struct_keys.Push(erased_name);
                seen_structs.Insert(std.Clone(ctx, erased_name), 1);
                erased_to_original.Insert(std.Clone(ctx, erased_name), std.Clone(ctx, key));
            }
            i_erase = i_erase + 1;
        }

        mut clone_helpers_needed: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
        mut i_chk := 0;
        while i_chk < len(erased_struct_keys) {
            mut struct_name := erased_struct_keys[i_chk];
            mut is_gen_arena := 0;
            mut suffix := "";
            if std.str_find(struct_name, "std_GenerationalArena_") == 0 {
                is_gen_arena = 1;
                suffix = std.str_slice(struct_name, 22, len(struct_name));
            } else if std.str_find(struct_name, "GenerationalArena_") == 0 {
                is_gen_arena = 1;
                suffix = std.str_slice(struct_name, 18, len(struct_name));
            }
            
            if is_gen_arena == 1 {
                mut normalized := suffix;
                mut d_idx := std.str_find(normalized, "__");
                while d_idx != 0 - 1 {
                    mut left := std.str_slice(normalized, 0, d_idx);
                    mut right := std.str_slice(normalized, d_idx + 2, len(normalized));
                    normalized = std.Concat(std.Concat(left, "@"), right);
                    d_idx = std.str_find(normalized, "__");
                }
                
                mut pos := codegen_rfind_char(normalized, 95, len(normalized));
                mut t_name := suffix;
                if pos != 0 - 1 {
                    t_name = std.str_slice(suffix, 0, pos);
                }
                clone_helpers_needed.Insert(std.Clone(ctx, t_name), 1);
            }
            i_chk = i_chk + 1;
        }

        mut work_list: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut keys_needed := typechecker.typechecker_get_sorted_keys_int(&clone_helpers_needed, ctx);
        mut i_key := 0;
        while i_key < len(keys_needed) {
            work_list.Push(std.Clone(ctx, keys_needed[i_key]));
            i_key = i_key + 1;
        }
        
        while len(work_list) > 0 {
            mut current := work_list.Pop();
            mut orig_name := codegen_find_original_struct_name(current, env, ctx);
            mut lookup_struct := (*env).struct_registry.get_opt(orig_name);
            match lookup_struct {
                Some { val } => {
                    mut layout := *val;
                    mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                    mut f_idx := 0;
                    while f_idx < len(f_keys) {
                        mut f_key := f_keys[f_idx];
                        mut f_type_lookup := layout.fields.get_opt(f_key);
                        match f_type_lookup {
                            Some { val } => {
                                mut f_type := *val;
                                if f_type.tag == 7 {
                                    mut nested_struct := f_type.Index.struct_name;
                                    mut clean_nested := nested_struct;
                                    if std.str_eq(nested_struct, "Any") == 1 {
                                        clean_nested = "SessionNode";
                                    }
                                    mut has_helper := 0;
                                    mut helper_lookup := clone_helpers_needed.get_opt(clean_nested);
                                    match helper_lookup {
                                        Some { val } => {
                                            has_helper = 1;
                                        }
                                        None => {
                                        }
                                    }
                                    if has_helper == 0 {
                                        clone_helpers_needed.Insert(std.Clone(ctx, clean_nested), 1);
                                        work_list.Push(std.Clone(ctx, clean_nested));
                                    }
                                }
                            }
                            None => {
                            }
                        }
                        f_idx = f_idx + 1;
                    }
                }
                None => {
                }
            } 
        }
        mut erased_helpers := typechecker.typechecker_get_sorted_keys_int(&clone_helpers_needed, ctx);

        mut i_fwd := 0;
        while i_fwd < len(erased_struct_keys) {
            mut key := erased_struct_keys[i_fwd];
            if std.str_eq(key, "std_Vector_str") == 0 &&
               std.str_eq(key, "os_Dir") == 0 &&
               std.str_eq(key, "os_DirEntry") == 0 &&
               std.str_eq(key, "os_ProcessResult") == 0 &&
               std.str_eq(key, "LookupResult_os_Dir") == 0 &&
               std.str_eq(key, "LookupResult_os_DirEntry") == 0 &&
               std.str_find(key, "CastResult_") == 0 - 1 {
                guard orig_key := erased_to_original.Get(key) else {
                    os.LogStr(std.Concat("🚨 CRITICAL COMPILER BUG: erased_to_original.Get failed for key: ", key));
                    os.Exit(1);
                    return std.Clone(ctx, "");
                }
                mut fwd := std.Concat("typedef struct ", key);
                fwd = std.Concat(fwd, " ");
                fwd = std.Concat(fwd, key);
                fwd = std.Concat(fwd, ";\n");
                chunks.Push(fwd);
            }
            i_fwd = i_fwd + 1;
        }
        
        // Forward declare all CastResult structures first
        mut i_cast_fwd := 0;
        while i_cast_fwd < len(erased_struct_keys) {
            mut key := erased_struct_keys[i_cast_fwd];
            if std.str_find(key, "CastResult_") == 0 - 1 &&
               std.str_find(key, "LookupResult_") == 0 - 1 {
                mut fwd := std.Concat("typedef struct CastResult_", key);
                fwd = std.Concat(fwd, " CastResult_");
                fwd = std.Concat(fwd, key);
                fwd = std.Concat(fwd, ";\n");
                chunks.Push(fwd);
            }
            i_cast_fwd = i_cast_fwd + 1;
        }
        chunks.Push("\n");

        // Generational Arena Clone Helper forward declarations
        if len(erased_helpers) > 0 {
            chunks.Push("// ====================================================\n");
            chunks.Push("// GENERATIONAL ARENA CLONE HELPER FORWARD DECLARATIONS\n");
            chunks.Push("// ====================================================\n");
            mut h_idx := 0;
            while h_idx < len(erased_helpers) {
                mut name := erased_helpers[h_idx];
                chunks.Push("int std_GenerationalArena_Clone_");
                chunks.Push(name);
                chunks.Push("(os_Arena* dest, os_Arena* src, int src_idx);\n");
                
                chunks.Push("void std_GenerationalArena_Step_");
                chunks.Push(name);
                chunks.Push("(void* arena_ptr);\n");
                h_idx = h_idx + 1;
            }
            chunks.Push("\n");
        }

        // Function Forward Declarations
        chunks.Push("// Function Forward Declarations\n");
        if codegen_has_thread_local_context(env, ctx) == 1 {
            chunks.Push("std_ThreadLocalContext os_GetThreadScratch(void);\n\n");
        }
        mut func_keys := typechecker.typechecker_get_sorted_keys_func(&((*env).function_registry), ctx);
        mut f_idx := 0;
        while f_idx < len(func_keys) {
            mut key := func_keys[f_idx];
            if std.str_eq(key, "main") == 0 {
                mut sig_lookup := (*env).function_registry.Get(key);
                if sig_lookup.Ok {
                    if sig_lookup.Val.is_compile_time_only == 0 &&
                       codegen_should_skip_fwd_decl(key) == 0 {
                        mut fwd_decl := codegen_gen_function_fwd_decl(key, sig_lookup.Val, env, ctx);
                        chunks.Push(fwd_decl);
                    }
                }
            }
            f_idx = f_idx + 1;
        }
        chunks.Push("\n");

        // 3. Structures Declarations
        chunks.Push("// Structures\n");
        mut i := 0;
        while i < len(erased_struct_keys) {
            mut key := erased_struct_keys[i];
            if std.str_eq(key, "std_Vector_str") == 0 &&
               std.str_eq(key, "os_Dir") == 0 &&
               std.str_eq(key, "os_DirEntry") == 0 &&
               std.str_eq(key, "os_ProcessResult") == 0 &&
               std.str_eq(key, "LookupResult_os_Dir") == 0 &&
               std.str_eq(key, "LookupResult_os_DirEntry") == 0 {
                guard orig_key := erased_to_original.Get(key) else {
                    os.LogStr(std.Concat("🚨 CRITICAL COMPILER BUG: erased_to_original.Get failed for key: ", key));
                    os.Exit(1);
                    return std.Clone(ctx, "");
                }
                
                mut is_template_instance := 0;
                if std.str_find(key, "_") != 0 - 1 {
                    is_template_instance = 1;
                }
                if is_template_instance == 1 {
                    codegen_log_trace("👁️", std.Format("codegen_generate: transpiling custom standard template instance %s", key), ctx);
                } else {
                    codegen_log_trace("👁️", std.Format("codegen_generate: transpiling structure layout for %s", key), ctx);
                }

                mut layout_lookup := (*env).struct_registry.Get(orig_key);
                if layout_lookup.Ok {
                    mut layout := layout_lookup.Val;
                    mut lookup_enum := (*env).enum_registry.Get(orig_key);
                    
                    if lookup_enum.Ok {
                        mut variants := lookup_enum.Val;
                        
                        // 1. Generate typedef enum for variant tags
                        mut enum_decl := std.Concat("typedef enum {\n", "");
                        mut j := 0;
                        while j < len(variants) {
                            mut variant := variants[j];
                            mut tag_line := std.Concat("    ", key);
                            tag_line = std.Concat(tag_line, "_Tag__");
                            tag_line = std.Concat(tag_line, variant);
                            tag_line = std.Concat(tag_line, " = ");
                            tag_line = std.Concat(tag_line, std.FormatInt(j));
                            tag_line = std.Concat(tag_line, ",\n");
                            enum_decl = std.Concat(enum_decl, tag_line);
                            j = j + 1;
                        }
                        enum_decl = std.Concat(enum_decl, "} ");
                        enum_decl = std.Concat(enum_decl, key);
                        enum_decl = std.Concat(enum_decl, "_Tag;\n\n");
                        chunks.Push(enum_decl);

                        // 2. Generate struct with anonymous union
                        mut struct_decl := std.Concat("struct ", key);
                        struct_decl = std.Concat(struct_decl, " {\n");
                        struct_decl = std.Concat(struct_decl, "    int tag;\n");
                        struct_decl = std.Concat(struct_decl, "    union {\n");

                        mut sorted_variants := codegen_sort_variants(variants, ctx);
                        mut k_var := 0;
                        while k_var < len(sorted_variants) {
                            mut variant := sorted_variants[k_var];
                            mut field_type_name := std.Concat(key, "_");
                            field_type_name = std.Concat(field_type_name, variant);
                            
                            mut var_line := std.Concat("        struct ", field_type_name);
                            var_line = std.Concat(var_line, " ");
                            var_line = std.Concat(var_line, variant);
                            var_line = std.Concat(var_line, ";\n");
                            struct_decl = std.Concat(struct_decl, var_line);
                            k_var = k_var + 1;
                        }
                        struct_decl = std.Concat(struct_decl, "    };\n");
                        struct_decl = std.Concat(struct_decl, "};\n\n");
                        chunks.Push(struct_decl);
                    } else {
                        mut struct_decl := std.Concat("struct ", key);
                        struct_decl = std.Concat(struct_decl, " {\n");
                        
                        mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                        if len(f_keys) == 0 {
                            struct_decl = std.Concat(struct_decl, "    char dummy;\n");
                        } else {
                            mut j := 0;
                            while j < len(f_keys) {
                                mut f_key := f_keys[j];
                                mut f_lookup := layout.fields.Get(f_key);
                                if f_lookup.Ok {
                                    mut f_c_type := codegen_get_c_type(f_lookup.Val, env, ctx);
                                    mut f_line := std.Concat("    ", f_c_type);
                                    f_line = std.Concat(f_line, " ");
                                    f_line = std.Concat(f_line, f_key);
                                    f_line = std.Concat(f_line, ";\n");
                                    struct_decl = std.Concat(struct_decl, f_line);
                                }
                                j = j + 1;
                            } 
                        }
                        struct_decl = std.Concat(struct_decl, "};\n\n");
                        chunks.Push(struct_decl);
                    }
                }
            }
            i = i + 1;
        }
        
        // 2. pthread_wrapper forward declarations
        chunks.Push("// pthread_wrapper forward declarations\n");
        mut fwd_p_idx := 0;
        while fwd_p_idx < len(programs) {
            mut prog := programs[fwd_p_idx];
            (*env).current_prefix = prefixes[fwd_p_idx];
            mut fwd_statements_vec_program_pass: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
            mut fwd_s_idx := 0;
            while fwd_s_idx < len(fwd_statements_vec_program_pass) {
                mut stmt := fwd_statements_vec_program_pass[fwd_s_idx];
                if stmt.tag == 3 { // FunctionDecl
                    mut params_vec_pthread_fwd: std.Vector[ast.Parameter[ctx], ctx] := ctx[stmt.FunctionDecl.params];
                    if len(params_vec_pthread_fwd) == 1 {
                        mut f_name := stmt.FunctionDecl.name;
                        mut namespaced_name := typechecker.env_resolve_namespaced_ident(env, f_name, ctx);
                        mut c_func_name := "";
                        mut char_idx := 0;
                        while char_idx < len(namespaced_name) {
                            mut b := std.str_byte_at(namespaced_name, char_idx);
                            if b == 46 { // '.'
                                c_func_name = std.Concat(c_func_name, "_");
                            } else {
                                c_func_name = std.Concat(c_func_name, std.str_slice(namespaced_name, char_idx, char_idx + 1));
                            }
                            char_idx = char_idx + 1;
                        }
                        mut decl := std.Concat("void* ", c_func_name);
                        decl = std.Concat(decl, "_pthread_wrapper(void* arg);\n");
                        chunks.Push(decl);
                    }
                }
                fwd_s_idx = fwd_s_idx + 1;
            }
            fwd_p_idx = fwd_p_idx + 1;
        }
        (*env).current_prefix = "";
        chunks.Push("\n");
        
        // 3. _IsValid Invariant Validator forward declarations
        chunks.Push("// Invariant Validator forward declarations\n");
        mut k := 0;
        while k < len(erased_struct_keys) {
            mut key := erased_struct_keys[k];
            mut t_struct: ast.Type[ctx];
            t_struct.tag = 8; // Struct
            t_struct.Struct.struct_name = key;
            t_struct.Struct.brand = empty[Index[str, ctx]];
            
            mut has_bool := codegen_has_boolean_fields(t_struct, env, ctx);
            if has_bool == 1 {
                mut decl := std.Concat("int ", key);
                decl = std.Concat(decl, "_IsValid(");
                decl = std.Concat(decl, key);
                decl = std.Concat(decl, "* req);\n");
                chunks.Push(decl);
            }
            k = k + 1;
        }
        chunks.Push("\n");
        
        // 3. _IsValid Invariant Validator implementations
        chunks.Push("// Invariant Validator implementations\n");
        mut m := 0;
        while m < len(erased_struct_keys) {
            mut key := erased_struct_keys[m];
            mut t_struct: ast.Type[ctx];
            t_struct.tag = 8; // Struct
            t_struct.Struct.struct_name = key;
            t_struct.Struct.brand = empty[Index[str, ctx]];
            
            mut has_bool := codegen_has_boolean_fields(t_struct, env, ctx);
            if has_bool == 1 {
                guard orig_key := erased_to_original.Get(key) else {
                    os.LogStr(std.Concat("🚨 CRITICAL COMPILER BUG: erased_to_original.Get failed for key: ", key));
                    os.Exit(1);
                    return std.Clone(ctx, "");
                }
                mut layout_lookup := (*env).struct_registry.get_opt(orig_key);
                match layout_lookup {
                    Some { val } => {
                        mut impl := codegen_gen_is_valid_helper(key, *val, env, ctx);
                        chunks.Push(impl);
                        chunks.Push("\n");
                    }
                    None => {
                    }
                }
            }
            m = m + 1;
        }

        // Generational Arena Clone Helper implementations
        if len(erased_helpers) > 0 {
            chunks.Push("// ====================================================\n");
            chunks.Push("// GENERATIONAL ARENA CLONE HELPER DEFINITIONS\n");
            chunks.Push("// ====================================================\n");
            mut h_idx := 0;
            while h_idx < len(erased_helpers) {
                mut name := erased_helpers[h_idx];
                mut impl := codegen_generate_clone_helper(name, env, ctx);
                chunks.Push(impl);
                h_idx = h_idx + 1;
            }
            chunks.Push("\n");
        }
        
        // 4. Statements in program (transpiled C)
        chunks.Push("// Program Statements\n");
        mut p_idx2 := 0;
        while p_idx2 < len(programs) {
            mut prog := programs[p_idx2];
            (*env).current_prefix = prefixes[p_idx2];
            mut statements_vec_program_emit: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
            mut s_idx := 0;
            while s_idx < len(statements_vec_program_emit) {
                mut emission_prefix := std.Clone(ctx, (*env).current_prefix);
                (*env).current_function_identity_scope = "";
                if statements_vec_program_emit[s_idx].tag == 3 && typechecker.typechecker_is_protected_resource_derived(statements_vec_program_emit[s_idx].FunctionDecl.name, env as *typechecker.TypeEnvironment[ctx], ctx) == 1 { (*env).protected_resource_preserve_concrete_types = 1; (*env).current_prefix = typechecker.typechecker_protected_resource_resolution_prefix(statements_vec_program_emit[s_idx].FunctionDecl.name, env as *typechecker.TypeEnvironment[ctx], ctx); (*env).current_function_identity_scope = typechecker.typechecker_protected_resource_identity(statements_vec_program_emit[s_idx].FunctionDecl.name, env as *typechecker.TypeEnvironment[ctx], ctx); }
                mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx.Set(stmt_idx, statements_vec_program_emit[s_idx]);
                mut stmt_c := codegen_generate_statement(stmt_idx, env, ctx);
                (*env).protected_resource_preserve_concrete_types = 0; (*env).current_prefix = emission_prefix; (*env).current_function_identity_scope = "";
                chunks.Push(stmt_c);
                s_idx = s_idx + 1;
            }
            p_idx2 = p_idx2 + 1;
        }
        (*env).current_prefix = "";

        if codegen_has_thread_local_context(env, ctx) == 1 {
            chunks.Push("std_ThreadLocalContext os_GetThreadScratch(void) {\n");
            chunks.Push("    std_ThreadLocalContext tl = { .arena = os_GetThreadScratch_raw(), ._phantom = NULL };\n");
            chunks.Push("    return tl;\n");
            chunks.Push("}\n\n");
        }
        
        mut generated := codegen_join_chunks(chunks, ctx);
        return std.Clone(ctx, generated);
    }
}
