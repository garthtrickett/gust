import "ast.gst" as ast;
import "token.gst" as token;
import "errors.gst" as errors;

type OriginSet[ctx] struct {
    map: std.HashMap[str, int, ctx]
}

func set_init(ctx: &Arena) Index[OriginSet[ctx], ctx] {
    mut s_idx: Index[OriginSet[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[s_idx].map = std.HashMapNew(ctx);
        return s_idx;
    }
}

func set_add(set: Index[OriginSet[ctx], ctx], element: str, ctx: &Arena) {
    unsafe {
        ctx[set].map.Insert(std.Clone(ctx, element), 1);
    }
}

func set_union(dest: Index[OriginSet[ctx], ctx], src: Index[OriginSet[ctx], ctx], ctx: &Arena) {
    unsafe {
        mut keys := ctx[src].map.Keys(ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            ctx[dest].map.Insert(std.Clone(ctx, key), 1);
            i = i + 1;
        }
    }
}

func set_contains(set: Index[OriginSet[ctx], ctx], element: str, ctx: &Arena) int {
    unsafe {
        return ctx[set].map.Get(element).Ok;
    }
}

func env_type_is_ephemeral_view(t: ast.Type[ctx], ctx: &Arena) int {
    unsafe {
        if t.tag == 5 { // Str
            return 1;
        }
        if t.tag == 6 { // Slice
            return 1;
        }
        if t.tag == 9 { // RawPointer
            return 1;
        }
        if t.tag == 8 { // Struct
            mut name := t.Struct.struct_name;
            if std.str_eq(name, "str") {
                return 1;
            }
            mut clean_name := name;
            mut d_idx := std.str_find(name, "__");
            if d_idx != 0 - 1 {
                clean_name = std.str_slice(name, d_idx + 2, len(name));
            }
            if len(clean_name) >= 11 && std.str_eq(std.str_slice(clean_name, 0, 11), "CastResult_") {
                return 1;
            }
            if len(clean_name) >= 13 && std.str_eq(std.str_slice(clean_name, 0, 13), "LookupResult_") {
                return 1;
            }
        }
        return 0;
    }
}

func get_expression_origins(expr_idx: Index[ast.Expression[ctx], ctx], env: *TypeEnvironment[ctx], ctx: &Arena) Index[OriginSet[ctx], ctx] { 
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return set_init(ctx);
        }
        mut expr := ctx[expr_idx];
        if expr.tag == 0 { // Identifier
            mut lookup := (*env).variable_origins.Get(expr.Identifier.name);
            if lookup.Ok {
                return lookup.Val;
            } else {
                mut s := set_init(ctx);
                set_add(s, expr.Identifier.name, ctx);
                return s;
            }
        }
        if expr.tag == 4 { // Move
            return get_expression_origins(expr.Move.expr, env, ctx);
        }
        if expr.tag == 5 { // Take
            return get_expression_origins(expr.Take.expr, env, ctx);
        }
        if expr.tag == 6 { // AddressOf
            return get_expression_origins(expr.AddressOf.expr, env, ctx);
        }
        if expr.tag == 7 { // Dereference
            return get_expression_origins(expr.Dereference.expr, env, ctx);
        }
        if expr.tag == 8 { // IndexAccess
            return get_expression_origins(expr.IndexAccess.allocator, env, ctx);
        }
        if expr.tag == 9 { // AsCast
            return get_expression_origins(expr.AsCast.left, env, ctx);
        }
        if expr.tag == 11 { // Selector
            return get_expression_origins(expr.Selector.left, env, ctx);
        }
        if expr.tag == 12 { // Call
            mut func_name := expression_to_string(expr.Call.function, ctx);
            mut resolved_func := env_resolve_namespaced_ident(env, func_name, ctx);
            if std.str_eq(resolved_func, "std_Format") || std.str_eq(resolved_func, "std.Format") || 
               std.str_eq(resolved_func, "std_FormatInt") || std.str_eq(resolved_func, "std.FormatInt") || 
               std.str_eq(resolved_func, "std_Concat") || std.str_eq(resolved_func, "std.Concat") || 
               std.str_eq(resolved_func, "os_ScratchAlloc") || std.str_eq(resolved_func, "os.ScratchAlloc") {
                mut s := set_init(ctx);
                set_add(s, "scratch", ctx);
                return s;
            } else {
                if std.str_eq(resolved_func, "std_Clone") || std.str_eq(resolved_func, "std.Clone") {
                    return set_init(ctx);
                }
                mut sig_lookup := (*env).function_registry.Get(resolved_func);
                if sig_lookup.Ok {
                    mut sig := sig_lookup.Val;
                    if env_type_is_ephemeral_view(sig.return_type, ctx) == 1 {
                        mut s := set_init(ctx);
                        mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                        mut i := 0;
                        while i < len(*args_vec) {
                            mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                            ctx[arg_idx] = (*args_vec)[i];
                            mut arg_origins := get_expression_origins(arg_idx, env, ctx);
                            set_union(s, arg_origins, ctx);
                            i = i + 1;
                        }
                        return s;
                    }
                }
            }
        }
        return set_init(ctx);
    }
}

func check_expression_internal(expr_idx: Index[ast.Expression[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) ast.Type[ctx] {
    unsafe {
        mut dummy: ast.Type[ctx];
        dummy.tag = 3; // Void
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return dummy;
        }
        mut expr := ctx[expr_idx];

        if expr.tag == 0 { // Identifier
            mut name := expr.Identifier.name;
            mut resolved_name := name;
            mut is_local := scope_contains(scope, name, ctx);
            if is_local == 0 {
                resolved_name = env_resolve_namespaced_ident(env, name, ctx);
            }
            mut t := scope_lookup(scope, resolved_name, ctx);

            // Check if resolved_name is moved
            if (*env).moved_vars.Get(resolved_name).Ok {
                mut err: errors.CompilerError[ctx];
                err.kind.tag = 2; // TypeError
                err.message = std.Clone(ctx, std.Concat("Semantic Error: Use of moved variable ", resolved_name));
                err.span = expr.Identifier.span;
                (*env).errors.Push(err);
            }

            // Check variable origins
            mut lookup_orig := (*env).variable_origins.Get(resolved_name);
            if lookup_orig.Ok {
                mut origs := lookup_orig.Val;
                mut keys := ctx[origs].map.Keys(ctx);
                mut i := 0;
                while i < len(keys) {
                    mut orig_name := keys[i];
                    if (*env).moved_vars.Get(orig_name).Ok {
                        mut err: errors.CompilerError[ctx];
                        err.kind.tag = 2; // TypeError
                        err.message = std.Clone(ctx, std.Concat("Semantic Error: Variable origin invalidated: ", orig_name));
                        err.span = expr.Identifier.span;
                        (*env).errors.Push(err);
                    }
                    i = i + 1;
                }
            }

            // Check allocator brand
            mut brand_name := "";
            if t.tag == 7 { // Index
                if t.Index.brand != empty[Index[str, ctx]] {
                    mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                    brand_name = *brand_str_ptr;
                }
            } else {
                if t.tag == 8 { // Struct
                    if t.Struct.brand != empty[Index[str, ctx]] {
                        mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                        brand_name = *brand_str_ptr;
                    }
                }
            }

            if std.str_eq(brand_name, "") == 0 {
                if (*env).moved_vars.Get(brand_name).Ok {
                    mut err: errors.CompilerError[ctx];
                    err.kind.tag = 2; // TypeError
                    err.message = std.Clone(ctx, std.Concat("Semantic Error: Allocator moved or freed: ", brand_name));
                    err.span = expr.Identifier.span;
                    (*env).errors.Push(err);
                }
            }
            return t;
        }
        if expr.tag == 1 { // Integer
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 2 { // String
            mut t: ast.Type[ctx];
            t.tag = 5; // Str
            return t;
        }
        if expr.tag == 3 { // Bool
            mut t: ast.Type[ctx];
            t.tag = 2; // Bool
            return t;
        }
        if expr.tag == 4 { // Move
            mut inner_idx := expr.Move.expr;
            mut inner := ctx[inner_idx];
            if inner.tag == 0 { // Identifier
                mut name := inner.Identifier.name;
                if (*env).open_directories.Get(name).Ok {
                    mut msg := std.Concat("Semantic Error: Directory resource variable '", name);
                    msg = std.Concat(msg, "' cannot be moved while open. Close it first.");
                    report_error(2, msg, expr.Move.span, env, ctx);
                }
                
                // Invalidate brand transitive use
                mut inner_type := check_expression(inner_idx, env, scope, ctx);
                if inner_type.tag == 4 { // Arena
                    mut var_origins_keys := (*env).variable_origins.Keys(ctx);
                    mut m := 0;
                    while m < len(var_origins_keys) {
                        mut var_name := var_origins_keys[m];
                        mut var_type_lookup := scope_lookup(scope, var_name, ctx);
                        mut brand := get_type_brand(var_type_lookup, ctx);
                        if std.str_eq(brand, name) == 1 {
                            (*env).moved_vars.Insert(std.Clone(ctx, var_name), 1);
                            (*env).open_directories.Remove(var_name);
                        }
                        m = m + 1;
                    }
                }
            }
            return check_expression(expr.Move.expr, env, scope, ctx);
        }
        if expr.tag == 5 { // Take
            return check_expression(expr.Take.expr, env, scope, ctx);
        }
        if expr.tag == 6 { // AddressOf
            mut inner := check_expression(expr.AddressOf.expr, env, scope, ctx);
            mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[t_idx].tag = 9; // RawPointer
            ctx[t_idx].RawPointer.inner = os.ArenaAlloc(ctx);
            ctx[ctx[t_idx].RawPointer.inner] = inner;
            return ctx[t_idx];
        }
        if expr.tag == 7 { // Dereference
            mut inner := check_expression(expr.Dereference.expr, env, scope, ctx);
            if inner.tag == 9 {
                return ctx[inner.RawPointer.inner];
            }
            return inner;
        }
        if expr.tag == 8 { // IndexAccess
            mut alloc_t := check_expression(expr.IndexAccess.allocator, env, scope, ctx);
            mut idx_t := check_expression(expr.IndexAccess.index, env, scope, ctx);
            if alloc_t.tag == 6 { // Slice
                return ctx[alloc_t.Slice.inner];
            }
            if idx_t.tag == 7 { // Index
                mut name := idx_t.Index.struct_name;
                if std.str_eq(name, "int") {
                    mut t: ast.Type[ctx];
                    t.tag = 0; // Int
                    return t;
                }
                if std.str_eq(name, "byte") {
                    mut t: ast.Type[ctx];
                    t.tag = 1; // Byte
                    return t;
                }
                if std.str_eq(name, "bool") {
                    mut t: ast.Type[ctx];
                    t.tag = 2; // Bool
                    return t;
                }
                if std.str_eq(name, "str") {
                    mut t: ast.Type[ctx];
                    t.tag = 5; // Str
                    return t;
                }
                mut t: ast.Type[ctx];
                t.tag = 8; // Struct
                t.Struct.struct_name = std.Clone(ctx, name);
                t.Struct.brand = idx_t.Index.brand;
                return t;
            }
            if alloc_t.tag == 8 { // Struct
                mut s_name := alloc_t.Struct.struct_name;
                mut lookup := (*env).struct_registry.Get(s_name);
                if lookup.Ok {
                    mut layout := lookup.Val;
                    mut data_lookup := layout.fields.Get("data");
                    if data_lookup.Ok {
                        mut data_type := data_lookup.Val;
                        if data_type.tag == 9 { // RawPointer
                            return ctx[data_type.RawPointer.inner];
                        } 
                    }
                    mut val_lookup := layout.fields.Get("values");
                    if val_lookup.Ok {
                        mut val_type := val_lookup.Val;
                        if val_type.tag == 9 { // RawPointer
                            return ctx[val_type.RawPointer.inner];
                        } 
                    }
                }
            }
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 9 { // AsCast
            mut left_type := check_expression(expr.AsCast.left, env, scope, ctx);
            mut resolved_target := env_resolve_type(env, ctx[expr.AsCast.target_type], ctx);
            return resolved_target;
        }
        if expr.tag == 10 { // Binary
            check_expression(expr.Binary.left, env, scope, ctx);
            check_expression(expr.Binary.right, env, scope, ctx);
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 11 { // Selector
            mut left_t := check_expression(expr.Selector.left, env, scope, ctx);
            mut left_str := expression_to_string(expr.Selector.left, ctx);
            if left_t.tag == 8 { // Struct
                mut struct_name := left_t.Struct.struct_name;
                mut clean_name := struct_name;
                if len(clean_name) >= 11 && std.str_eq(std.str_slice(clean_name, 0, 11), "CastResult_") {
                    if std.str_eq(expr.Selector.right, "Ok") {
                        mut t: ast.Type[ctx];
                        t.tag = 0; // Int
                        return t;
                    }
                    if std.str_eq(expr.Selector.right, "Val") {
                        if (*env).checked_results.Get(left_str).Ok == 0 {
                            mut msg := "Semantic Error: Accessing the .Val payload of an unchecked result wrapper ";
                            msg = std.Concat(msg, left_str);
                            report_error(2, msg, expr.Selector.span, env, ctx);
                        }
                        mut target := std.str_slice(clean_name, 11, len(clean_name));
                        mut t: ast.Type[ctx];
                        t.tag = 8; // Struct
                        t.Struct.struct_name = std.Clone(ctx, target);
                        t.Struct.brand = left_t.Struct.brand;
                        return t;
                    }
                }
                if len(clean_name) >= 13 && std.str_eq(std.str_slice(clean_name, 0, 13), "LookupResult_") {
                    if std.str_eq(expr.Selector.right, "Ok") {
                        mut t: ast.Type[ctx];
                        t.tag = 0; // Int
                        return t;
                    }
                    if std.str_eq(expr.Selector.right, "Val") {
                        if (*env).checked_results.Get(left_str).Ok == 0 {
                            mut msg := "Semantic Error: Accessing the .Val payload of an unchecked result wrapper ";
                            msg = std.Concat(msg, left_str);
                            report_error(2, msg, expr.Selector.span, env, ctx);
                        }
                        mut target := std.str_slice(clean_name, 13, len(clean_name));
                        if std.str_eq(target, "int") {
                            mut t: ast.Type[ctx];
                            t.tag = 0; // Int
                            return t;
                        }
                        mut t: ast.Type[ctx];
                        t.tag = 8; // Struct
                        t.Struct.struct_name = std.Clone(ctx, target);
                        t.Struct.brand = left_t.Struct.brand;
                        return t;
                    }
                }
                mut lookup_struct := (*env).struct_registry.Get(struct_name);
                if lookup_struct.Ok {
                    mut field_lookup := lookup_struct.Val.fields.Get(expr.Selector.right);
                    if field_lookup.Ok {
                        return field_lookup.Val;
                    }
                }
            }
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 12 { // Call
            mut func_name := expression_to_string(expr.Call.function, ctx);
            mut resolved_func := env_resolve_namespaced_ident(env, func_name, ctx);

            if std.str_eq(resolved_func, "os_ArenaAlloc") || std.str_eq(resolved_func, "os.ArenaAlloc") {
                mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                if len(*args_vec) != 1 {
                    mut msg := "Semantic Error: os_ArenaAlloc expects exactly 1 argument (the allocator variable)";
                    report_error(2, msg, expr.Call.span, env, ctx);
                }
                mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[arg0_idx] = (*args_vec)[0];
                mut arg_type := check_expression(arg0_idx, env, scope, ctx);
                mut brand_name := get_root_variable(arg0_idx, ctx);
                return make_type_index("Any", brand_name, ctx);
            }
            
            // Spawn / Concurrency Checks
            if std.str_eq(resolved_func, "std_Spawn") || std.str_eq(resolved_func, "std.Spawn") {
                mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                if len(*args_vec) == 2 {
                    mut task_func_expr := (*args_vec)[0];
                    mut task_arg_expr := (*args_vec)[1];
                    mut task_func_name := "";
                    unsafe {
                        if task_func_expr.tag == 0 {
                            task_func_name = task_func_expr.Identifier.name;
                        }
                    }
                    mut resolved_task_func := env_resolve_namespaced_ident(env, task_func_name, ctx);
                    mut sig_lookup := (*env).function_registry.Get(resolved_task_func);
                    if sig_lookup.Ok {
                        mut sig := sig_lookup.Val;
                        if len(sig.params) == 1 {
                            mut first_param_type := sig.params[0];
                            mut param_brand := get_type_brand(first_param_type, ctx);
                            if std.str_eq(param_brand, "") == 0 {
                                mut task_arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                                ctx[task_arg_idx] = task_arg_expr;
                                mut arg_origins := get_expression_origins(task_arg_idx, env, ctx);
                                if (*env).current_function_local_vars != empty[Index[OriginSet[ctx], ctx]] {
                                    mut local_vars := (*env).current_function_local_vars;
                                    mut local_keys := ctx[local_vars].map.Keys(ctx);
                                    mut m := 0;
                                    while m < len(local_keys) {
                                        mut origin := local_keys[m];
                                        if std.str_eq(origin, param_brand) == 0 {
                                            if set_contains(arg_origins, origin, ctx) == 1 {
                                                mut msg := "Semantic Error: Thread-safety violation. Branded context has origin tracing back to thread-local stack variable '";
                                                msg = std.Concat(msg, origin);
                                                msg = std.Concat(msg, "', preventing safe handoff across thread-spawning boundaries");
                                                report_error(2, msg, get_expression_span(task_arg_idx, ctx), env, ctx);
                                            }
                                        }
                                        m = m + 1;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if std.str_eq(resolved_func, "os_CloseDir") || std.str_eq(resolved_func, "os.CloseDir") {
                mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                if len(*args_vec) == 1 {
                    mut arg_expr := (*args_vec)[0];
                    mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[arg_idx] = arg_expr;
                    mut arg_name := get_root_variable(arg_idx, ctx);
                    if std.str_eq(arg_name, "") == 0 {
                        (*env).open_directories.Remove(arg_name);
                    }
                }
            }

            if std.str_eq(resolved_func, "std_Clone") || std.str_eq(resolved_func, "std.Clone") {
                mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                if len(*args_vec) == 2 {
                    mut val_expr_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[val_expr_idx] = (*args_vec)[1];
                    mut val_type := check_expression(val_expr_idx, env, scope, ctx);
                    return val_type;
                }
            }

            if std.str_eq(resolved_func, "std_ChannelNew") || std.str_eq(resolved_func, "std.ChannelNew") ||
               std.str_eq(resolved_func, "std_MutexNew") || std.str_eq(resolved_func, "std.MutexNew") ||
               std.str_eq(resolved_func, "std_VectorNew") || std.str_eq(resolved_func, "std.VectorNew") ||
               std.str_eq(resolved_func, "std_HashMapNew") || std.str_eq(resolved_func, "std.HashMapNew") ||
               std.str_eq(resolved_func, "std_PoolNew") || std.str_eq(resolved_func, "std.PoolNew") ||
               std.str_eq(resolved_func, "std_GraphNew") || std.str_eq(resolved_func, "std.GraphNew") {
                mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
                if len(*args_vec) == 1 {
                    mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[arg0_idx] = (*args_vec)[0];
                    mut brand_name := get_root_variable(arg0_idx, ctx);
                    
                    mut ret_name := "std_Channel_Any";
                    if std.str_eq(resolved_func, "std_MutexNew") || std.str_eq(resolved_func, "std.MutexNew") {
                        ret_name = "std_Mutex_Any";
                    } else if std.str_eq(resolved_func, "std_VectorNew") || std.str_eq(resolved_func, "std.VectorNew") {
                        ret_name = "Vector_Any";
                    } else if std.str_eq(resolved_func, "std_HashMapNew") || std.str_eq(resolved_func, "std.HashMapNew") {
                        ret_name = "HashMap_Any";
                    } else if std.str_eq(resolved_func, "std_PoolNew") || std.str_eq(resolved_func, "std.PoolNew") {
                        ret_name = "Pool_Any";
                    } else if std.str_eq(resolved_func, "std_GraphNew") || std.str_eq(resolved_func, "std.GraphNew") {
                        ret_name = "std_Graph_Any";
                    }
                    return make_type_struct(ret_name, brand_name, ctx);
                }
            }

            mut sig_lookup := (*env).function_registry.Get(resolved_func);
            if sig_lookup.Ok {
                return sig_lookup.Val.return_type;
            }
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 13 { // Empty
            return env_resolve_type(env, ctx[expr.Empty.target_type], ctx);
        }
        return dummy;
    }
}

func check_expression(expr_idx: Index[ast.Expression[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) ast.Type[ctx] {
    mut t := check_expression_internal(expr_idx, env, scope, ctx);
    unsafe {
        mut final_span := get_expression_span(expr_idx, ctx);
        (*env).resolved_types.Insert(final_span.start.offset, t);
    }
    return t;
}

type StructLayout[ctx] struct {
    brand: Index[str, ctx],
    fields: std.HashMap[str, ast.Type[ctx], ctx]
}

type FunctionSignature[ctx] struct {
    param_names: std.Vector[str, ctx],
    params: std.Vector[ast.Type[ctx], ctx],
    return_type: ast.Type[ctx],
    return_origins: Index[OriginSet[ctx], ctx]
}

type Scope[ctx] struct {
    parent: Index[Scope[ctx], ctx],
    bindings: std.HashMap[str, ast.Type[ctx], ctx]
}

type StructTemplate[ctx] struct {
    generics: Index[std.Vector[str, ctx], ctx],
    fields: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx]
}

type EnumTemplate[ctx] struct {
    generics: Index[std.Vector[str, ctx], ctx],
    variants: Index[std.Vector[ast.VariantDef[ctx], ctx], ctx]
}

func scope_new(parent: Index[Scope[ctx], ctx], ctx: &Arena) Index[Scope[ctx], ctx] {
    mut scope_idx: Index[Scope[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[scope_idx].parent = parent;
        ctx[scope_idx].bindings = std.HashMapNew(ctx);
    }
    if parent == empty[Index[Scope[ctx], ctx]] {
        typechecker_log_trace("🗄️", "scope_new: spawned root scope", ctx);
    } else {
        typechecker_log_trace("🗄️", "scope_new: spawned child scope under parent", ctx);
    }
    return scope_idx;
}

func scope_insert(scope: Index[Scope[ctx], ctx], name: str, t: ast.Type[ctx], ctx: &Arena) {
    unsafe {
        ctx[scope].bindings.Insert(std.Clone(ctx, name), t);
    }
    mut t_str := ast.serialize_type(t, ctx);
    mut msg := std.Format("scope_insert: bound variable '%s' to type %s", name, t_str);
    typechecker_log_trace("🗄️", msg, ctx);
}

func scope_contains(scope: Index[Scope[ctx], ctx], name: str, ctx: &Arena) int {
    mut curr_scope := scope;
    while curr_scope != empty[Index[Scope[ctx], ctx]] {
        unsafe {
            if ctx[curr_scope].bindings.Get(name).Ok {
                return 1;
            }
            curr_scope = ctx[curr_scope].parent;
        }
    }
    return 0;
}

func scope_lookup(scope: Index[Scope[ctx], ctx], name: str, ctx: &Arena) ast.Type[ctx] {
    mut curr_scope := scope;
    while curr_scope != empty[Index[Scope[ctx], ctx]] {
        unsafe {
            if ctx[curr_scope].bindings.Get(name).Ok {
                return ctx[curr_scope].bindings.Get(name).Val;
            }
            curr_scope = ctx[curr_scope].parent;
        }
    }
    mut dummy: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[dummy].tag = 3; // Void
        return ctx[dummy];
    }
}

type TypeEnvironment[ctx] struct {
    struct_registry: std.HashMap[str, StructLayout[ctx], ctx],
    struct_templates: std.HashMap[str, StructTemplate[ctx], ctx],
    enum_templates: std.HashMap[str, EnumTemplate[ctx], ctx],
    function_registry: std.HashMap[str, FunctionSignature[ctx], ctx],
    variable_types: std.HashMap[str, ast.Type[ctx], ctx],
    resolved_types: std.HashMap[int, ast.Type[ctx], ctx],
    enum_registry: std.HashMap[str, std.Vector[str, ctx], ctx],
    current_prefix: str,
    imports: std.HashMap[str, str, ctx],
    variable_origins: std.HashMap[str, Index[OriginSet[ctx], ctx], ctx],
    moved_vars: std.HashMap[str, int, ctx],
    open_directories: std.HashMap[str, int, ctx],
    errors: std.Vector[errors.CompilerError[ctx], ctx],
    expected_return_type: Index[ast.Type[ctx], ctx],
    current_function_return_origins: Index[OriginSet[ctx], ctx],
    current_function_inout_params: Index[std.Vector[str, ctx], ctx],
    current_function_local_vars: Index[OriginSet[ctx], ctx],
    checked_results: std.HashMap[str, int, ctx],
    in_unsafe_block: int
}

func make_type_int() ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 0; // Int
    return t;
}

func make_type_byte() ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 1; // Byte
    return t;
}

func make_type_bool() ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 2; // Bool
    return t;
}

func make_type_arena() ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 4; // Arena
    return t;
}

func make_type_str() ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 5; // Str
    return t;
}

func make_type_pointer(inner: ast.Type[ctx], ctx: &Arena) ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 9; // RawPointer
    unsafe {
        t.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx[t.RawPointer.inner] = inner;
    }
    return t;
}

func make_type_struct(name: str, brand_name: str, ctx: &Arena) ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 8; // Struct
    t.Struct.struct_name = std.Clone(ctx, name);
    if std.str_eq(brand_name, "") {
        t.Struct.brand = empty[Index[str, ctx]];
    } else {
        unsafe {
            t.Struct.brand = os.ArenaAlloc(ctx) as Index[str, ctx];
            mut ptr := &ctx[t.Struct.brand] as *str;
            *ptr = std.Clone(ctx, brand_name);
        }
    }
    return t;
}

func make_type_index(struct_name: str, brand_name: str, ctx: &Arena) ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 7; // Index
    t.Index.struct_name = std.Clone(ctx, struct_name);
    if std.str_eq(brand_name, "") {
        t.Index.brand = empty[Index[str, ctx]];
    } else {
        unsafe {
            t.Index.brand = os.ArenaAlloc(ctx) as Index[str, ctx];
            mut ptr := &ctx[t.Index.brand] as *str;
            *ptr = std.Clone(ctx, brand_name);
        }
    }
    return t;
}

func make_type_generic(name: str, args: std.Vector[ast.Type[ctx], ctx], ctx: &Arena) ast.Type[ctx] {
    mut t: ast.Type[ctx];
    t.tag = 10; // Generic
    t.Generic.name = std.Clone(ctx, name);
    unsafe {
        t.Generic.args = os.ArenaAlloc(ctx);
        mut dest_args := &ctx[t.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
        *dest_args = args;
    }
    return t;
}

func make_field(name: str, t: ast.Type[ctx], ctx: &Arena) ast.FieldDef[ctx] {
    mut f: ast.FieldDef[ctx];
    f.name = std.Clone(ctx, name);
    f.field_type = t;
    return f;
}

func strip_brand_prefix(brand: str, ctx: &Arena) str {
    mut last_double_underscore := 0 - 1;
    mut i := 0;
    while i < len(brand) - 1 {
        mut b1 := std.str_byte_at(brand, i);
        mut b2 := std.str_byte_at(brand, i + 1);
        if b1 == 95 && b2 == 95 { // "__"
            last_double_underscore = i;
        }
        i = i + 1;
    }
    if last_double_underscore == 0 - 1 {
        return brand;
    }
    return std.str_slice(brand, last_double_underscore + 2, len(brand));
}

func typechecker_ends_with(s: str, suffix: str) int {
    mut len_s := len(s);
    mut len_suffix := len(suffix);
    if len_s < len_suffix {
        return 0;
    }
    mut end_part := std.str_slice(s, len_s - len_suffix, len_s);
    return std.str_eq(end_part, suffix);
}

func get_type_ident(t: ast.Type[ctx], ctx: &Arena) str {
    unsafe {
        mut base := "";
        if t.tag == 0 { // Int
            base = "int";
        } else if t.tag == 1 { // Byte
            base = "byte";
        } else if t.tag == 2 { // Bool
            base = "bool";
        } else if t.tag == 3 { // Void
            base = "void";
        } else if t.tag == 4 { // Arena
            base = "Arena";
        } else if t.tag == 5 { // Str
            base = "str";
        } else if t.tag == 6 { // Slice
            mut inner_t := ctx[t.Slice.inner];
            base = std.Concat("Slice_", get_type_ident(inner_t, ctx));
        } else if t.tag == 7 { // Index
            base = std.Concat("Index_", t.Index.struct_name);
            if t.Index.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                mut clean_b := strip_brand_prefix(*brand_str_ptr, ctx);
                mut suffix := std.Concat("_", clean_b);
                if typechecker_ends_with(t.Index.struct_name, suffix) == 0 {
                    base = std.Concat(base, suffix);
                }
            }
        } else if t.tag == 8 { // Struct
            base = t.Struct.struct_name;
            if t.Struct.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                mut clean_b := strip_brand_prefix(*brand_str_ptr, ctx);
                mut suffix := std.Concat("_", clean_b);
                if typechecker_ends_with(base, suffix) == 0 {
                    base = std.Concat(base, suffix);
                }
            }
        } else if t.tag == 9 { // RawPointer
            mut inner_t := ctx[t.RawPointer.inner];
            base = std.Concat(get_type_ident(inner_t, ctx), "_ptr");
        } else if t.tag == 10 { // Generic
            base = get_monomorphized_name(t.Generic.name, t.Generic.args, ctx);
        } else {
            base = "unknown";
        }

        mut out := "";
        mut i := 0;
        while i < len(base) {
            mut b := std.str_byte_at(base, i);
            if b == 46 { // '.'
                out = std.Concat(out, "_");
            } else {
                mut char_slice := std.str_slice(base, i, i + 1);
                out = std.Concat(out, char_slice);
            }
            i = i + 1;
        }
        return std.Clone(ctx, out);
    }
}

func get_monomorphized_name(template_name: str, args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx], ctx: &Arena) str {
    unsafe {
        mut args_vec := &ctx[args_idx] as *std.Vector[ast.Type[ctx], ctx];
        mut arg_names := "";
        mut i := 0;
        while i < len(*args_vec) {
            if i > 0 {
                arg_names = std.Concat(arg_names, "_");
            }
            mut arg_name := get_type_ident((*args_vec)[i], ctx);
            arg_names = std.Concat(arg_names, arg_name);
            i = i + 1;
        }
        mut name := std.Concat(template_name, "_");
        name = std.Concat(name, arg_names);

        mut out := "";
        mut j := 0;
        while j < len(name) {
            mut b := std.str_byte_at(name, j);
            if b == 46 { // '.'
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

func substitute_generics(env: *TypeEnvironment[ctx], t: ast.Type[ctx], map: std.HashMap[str, ast.Type[ctx], ctx], ctx: &Arena) ast.Type[ctx] {
    unsafe { 
        mut res_type: ast.Type[ctx];
        if t.tag == 8 { // Struct
            mut name := t.Struct.struct_name;
            mut lookup := map.Get(name);
            if lookup.Ok {
                res_type = lookup.Val;
                mut before_str := name;
                mut after_str := ast.serialize_type(res_type, ctx);
                mut subst_msg := std.Format("substitute_generics: replaced placeholder '%s' with %s", before_str, after_str);
                typechecker_log_trace("👁️", subst_msg, ctx);
            } else {
                mut parts := std.str_split(name, "_", ctx);
                mut changed := 0;
                mut i := 0;
                while i < len(parts) {
                    mut part := parts[i];
                    mut part_lookup := map.Get(part);
                    if part_lookup.Ok {
                        parts[i] = get_type_ident(part_lookup.Val, ctx);
                        changed = 1;
                    }
                    i = i + 1;
                }
                mut new_name := name;
                if changed == 1 {
                    new_name = ast.ast_join_strings(parts, "_", ctx);
                }
                
                mut final_lookup := map.Get(new_name);
                if final_lookup.Ok { 
                    res_type = final_lookup.Val;
                } else {
                    mut new_brand := t.Struct.brand;
                    if t.Struct.brand != empty[Index[str, ctx]] {
                        mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                        mut brand_lookup := map.Get(*brand_str_ptr);
                        if brand_lookup.Ok {
                            mut b_type := brand_lookup.Val;
                            if b_type.tag == 8 { // Struct
                                new_brand = os.ArenaAlloc(ctx) as Index[str, ctx];
                                mut ptr := &ctx[new_brand] as *str;
                                *ptr = std.Clone(ctx, b_type.Struct.struct_name);
                            }
                        }
                    }
                    res_type.tag = 8; // Struct
                    res_type.Struct.struct_name = std.Clone(ctx, new_name);
                    res_type.Struct.brand = new_brand;
                }
            }
        } else if t.tag == 7 { // Index
            mut name := t.Index.struct_name;
            mut lookup := map.Get(name);
            mut new_struct := name;
            if lookup.Ok {
                mut b_type := lookup.Val;
                if b_type.tag == 8 { // Struct
                    new_struct = b_type.Struct.struct_name;
                } else {
                    new_struct = get_type_ident(b_type, ctx);
                }
                mut before_str := name;
                mut after_str := ast.serialize_type(b_type, ctx);
                mut subst_msg := std.Format("substitute_generics: replaced placeholder '%s' with %s", before_str, after_str);
                typechecker_log_trace("👁️", subst_msg, ctx);
            } else {
                mut parts := std.str_split(name, "_", ctx);
                mut changed := 0;
                mut i := 0;
                while i < len(parts) {
                    mut part := parts[i];
                    mut part_lookup := map.Get(part);
                    if part_lookup.Ok {
                        parts[i] = get_type_ident(part_lookup.Val, ctx);
                        changed = 1;
                    }
                    i = i + 1;
                }
                if changed == 1 {
                    new_struct = ast.ast_join_strings(parts, "_", ctx);
                }
            }

            mut final_lookup := map.Get(new_struct);
            mut final_struct := new_struct;
            if final_lookup.Ok {
                mut b_type := final_lookup.Val;
                if b_type.tag == 8 { // Struct
                    final_struct = b_type.Struct.struct_name;
                }
            }

            mut new_brand := t.Index.brand;
            if t.Index.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                mut brand_lookup := map.Get(*brand_str_ptr);
                if brand_lookup.Ok {
                    mut b_type := brand_lookup.Val;
                    if b_type.tag == 8 { // Struct
                        new_brand = os.ArenaAlloc(ctx) as Index[str, ctx];
                        mut ptr := &ctx[new_brand] as *str;
                        *ptr = std.Clone(ctx, b_type.Struct.struct_name);
                    }
                }
            }

            res_type.tag = 7; // Index
            res_type.Index.struct_name = std.Clone(ctx, final_struct);
            res_type.Index.brand = new_brand;
        } else if t.tag == 9 { // RawPointer
            mut inner := ctx[t.RawPointer.inner];
            mut sub_inner := substitute_generics(env, inner, map, ctx);
            res_type = make_type_pointer(sub_inner, ctx);
        } else if t.tag == 6 { // Slice
            mut inner := ctx[t.Slice.inner];
            mut sub_inner := substitute_generics(env, inner, map, ctx);
            mut s: ast.Type[ctx];
            s.tag = 6; // Slice
            s.Slice.inner = os.ArenaAlloc(ctx);
            ctx[s.Slice.inner] = sub_inner;
            res_type = s;
        } else if t.tag == 10 { // Generic
            mut args_vec := &ctx[t.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
            mut sub_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            mut i := 0;
            while i < len(*args_vec) {
                mut arg := (*args_vec)[i];
                sub_args.Push(substitute_generics(env, arg, map, ctx));
                i = i + 1;
            }
            res_type = make_type_generic(t.Generic.name, sub_args, ctx);
        } else {
            res_type = t;
        }

        mut resolved_namespaced := env_resolve_type(env, res_type, ctx);
        return resolved_namespaced;
    }
}

func monomorphize(env: *TypeEnvironment[ctx], template_name: str, args: std.Vector[ast.Type[ctx], ctx], ctx: &Arena) errors.Result[ast.Type[ctx], ctx] { 
    unsafe {
        mut old_prefix := (*env).current_prefix;
        mut old_imports := (*env).imports;

        mut template_prefix := "";
        mut pos := std.str_find(template_name, "__");
        if pos != 0 - 1 {
            template_prefix = std.str_slice(template_name, 0, pos + 2);
        }

        if std.str_eq(template_prefix, "") == 0 {
            (*env).current_prefix = std.Clone(ctx, template_prefix);
        }

        mut res := monomorphize_impl(env, template_name, args, ctx);

        (*env).current_prefix = old_prefix;
        (*env).imports = old_imports;

        return res;
    }
}

func monomorphize_impl(env: *TypeEnvironment[ctx], template_name: str, args: std.Vector[ast.Type[ctx], ctx], ctx: &Arena) errors.Result[ast.Type[ctx], ctx] {
    unsafe {
        mut args_idx_start: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[args_idx_start] = args;
        mut start_args_name := get_monomorphized_name(template_name, args_idx_start, ctx);
        mut start_msg := std.Format("monomorphize_impl: start for %s", start_args_name);
        typechecker_log_trace("🔄", start_msg, ctx);

        mut res: errors.Result[ast.Type[ctx], ctx];
        res.tag = 0; // Ok

        // 1. Check Enum Templates
        mut enum_lookup := (*env).enum_templates.Get(template_name);
        if enum_lookup.Ok {
            mut template := enum_lookup.Val;
            mut generics_vec := &ctx[template.generics] as *std.Vector[str, ctx];
            if len(*generics_vec) != len(args) {
                mut err: Index[errors.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[err].kind.tag = 2; // TypeError
                mut msg := std.Concat("Semantic Error: Template '", template_name);
                msg = std.Concat(msg, "' expects ");
                msg = std.Concat(msg, std.FormatInt(len(*generics_vec)));
                msg = std.Concat(msg, " generic arguments but got ");
                msg = std.Concat(msg, std.FormatInt(len(args)));
                ctx[err].message = std.Clone(ctx, msg);
                res.tag = 1; // Err
                res.Err.error = err;
                return res;
            }

            mut substitution_map: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
            mut i := 0;
            while i < len(*generics_vec) {
                substitution_map.Insert(std.Clone(ctx, (*generics_vec)[i]), args[i]);
                i = i + 1;
            }

            mut args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[args_idx] = args;
            mut concrete_name := get_monomorphized_name(template_name, args_idx, ctx);

            mut brand: Index[str, ctx] := empty[Index[str, ctx]];
            mut j := 0;
            while j < len(*generics_vec) {
                mut g_name := (*generics_vec)[j];
                if std.str_eq(g_name, "ctx") || std.str_eq(g_name, "connCtx") || std.str_eq(g_name, "arena") || std.str_eq(g_name, "a") {
                    mut arg := args[j];
                    if arg.tag == 8 { // Struct
                        brand = os.ArenaAlloc(ctx) as Index[str, ctx];
                        mut ptr := &ctx[brand] as *str;
                        *ptr = std.Clone(ctx, arg.Struct.struct_name);
                    }
                }
                j = j + 1;
            }

            mut existing := (*env).struct_registry.Get(concrete_name);
            if existing.Ok == 0 {
                mut placeholder: StructLayout[ctx];
                placeholder.brand = brand;
                placeholder.fields = std.HashMapNew(ctx);
                (*env).struct_registry.Insert(std.Clone(ctx, concrete_name), placeholder);

                mut enum_fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
                mut t_int: ast.Type[ctx];
                t_int.tag = 0; // Int
                enum_fields.Insert(std.Clone(ctx, "tag"), t_int);

                mut variants_vec := &ctx[template.variants] as *std.Vector[ast.VariantDef[ctx], ctx];
                mut concrete_variants: std.Vector[str, ctx] := std.VectorNew(ctx);
                mut v_idx := 0;
                while v_idx < len(*variants_vec) {
                    mut variant := (*variants_vec)[v_idx];
                    concrete_variants.Push(std.Clone(ctx, variant.name));
                    mut concrete_variant_struct_name := std.Concat(concrete_name, "_");
                    concrete_variant_struct_name = std.Concat(concrete_variant_struct_name, variant.name);

                    mut variant_fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
                    mut vfields_vec := &ctx[variant.fields] as *std.Vector[ast.FieldDef[ctx], ctx];
                    mut f_idx := 0;
                    while f_idx < len(*vfields_vec) {
                        mut field := (*vfields_vec)[f_idx];
                        mut substituted_type := substitute_generics(env, field.field_type, substitution_map, ctx);
                        mut resolved_field_type := env_resolve_type(env, substituted_type, ctx);

                        if resolved_field_type.tag == 8 { // Struct
                            mut sub_layout_lookup := (*env).struct_registry.Get(resolved_field_type.Struct.struct_name);
                            if sub_layout_lookup.Ok {
                                if sub_layout_lookup.Val.fields.len > 2 {
                                // Skip check if the target struct is an enum (which has a "tag" field)
                                if sub_layout_lookup.Val.fields.Get("tag").Ok == 0 {
                                    mut err: Index[errors.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
                                        ctx[err].kind.tag = 2; // TypeError
                                        mut msg := std.Concat("Semantic Error: Variant '", variant.name);
                                        msg = std.Concat(msg, "' contains a large enum variant payload struct '");
                                        msg = std.Concat(msg, resolved_field_type.Struct.struct_name);
                                        msg = std.Concat(msg, "' (3 fields). Use Index, or pointer indirection to avoid memory bloat.");
                                        ctx[err].message = std.Clone(ctx, msg);
                                        res.tag = 1; // Err
                                        res.Err.error = err;
                                        return res;
                                    }
                                }
                            }
                        }

                        variant_fields.Insert(std.Clone(ctx, field.name), resolved_field_type);
                        f_idx = f_idx + 1;
                    }

                    mut variant_layout: StructLayout[ctx];
                    variant_layout.brand = brand;
                    variant_layout.fields = variant_fields;
                    (*env).struct_registry.Insert(std.Clone(ctx, concrete_variant_struct_name), variant_layout);

                    mut t_variant: ast.Type[ctx];
                    t_variant.tag = 8; // Struct
                    t_variant.Struct.struct_name = std.Clone(ctx, concrete_variant_struct_name);
                    t_variant.Struct.brand = brand;
                    enum_fields.Insert(std.Clone(ctx, variant.name), t_variant);

                    v_idx = v_idx + 1;
                }

                placeholder.fields = enum_fields;
                (*env).struct_registry.Insert(std.Clone(ctx, concrete_name), placeholder);
                (*env).enum_registry.Insert(std.Clone(ctx, concrete_name), concrete_variants);

                mut success_msg := std.Format("monomorphize_impl: successfully instantiated enum '%s'", concrete_name);
                typechecker_log_trace("🔄", success_msg, ctx);
            }

            res.Ok.val.tag = 8; // Struct
            res.Ok.val.Struct.struct_name = std.Clone(ctx, concrete_name);
            res.Ok.val.Struct.brand = brand;
            return res;
        }

        // 2. Check Struct Templates
        mut struct_lookup := (*env).struct_templates.Get(template_name);
        if struct_lookup.Ok {
            mut template := struct_lookup.Val;
            mut generics_vec := &ctx[template.generics] as *std.Vector[str, ctx];
            if len(*generics_vec) != len(args) {
                mut err: Index[errors.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[err].kind.tag = 2; // TypeError
                mut msg := std.Concat("Semantic Error: Template '", template_name);
                msg = std.Concat(msg, "' expects ");
                msg = std.Concat(msg, std.FormatInt(len(*generics_vec)));
                msg = std.Concat(msg, " generic arguments but got ");
                msg = std.Concat(msg, std.FormatInt(len(args)));
                ctx[err].message = std.Clone(ctx, msg);
                res.tag = 1; // Err
                res.Err.error = err;
                return res;
            }

            mut substitution_map: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
            mut i := 0;
            while i < len(*generics_vec) {
                substitution_map.Insert(std.Clone(ctx, (*generics_vec)[i]), args[i]);
                i = i + 1;
            }

            mut args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[args_idx] = args;
            mut concrete_name := get_monomorphized_name(template_name, args_idx, ctx);

            mut brand: Index[str, ctx] := empty[Index[str, ctx]];
            mut j := 0;
            while j < len(*generics_vec) {
                mut g_name := (*generics_vec)[j];
                if std.str_eq(g_name, "ctx") || std.str_eq(g_name, "connCtx") || std.str_eq(g_name, "arena") || std.str_eq(g_name, "a") {
                    mut arg := args[j];
                    if arg.tag == 8 { // Struct
                        brand = os.ArenaAlloc(ctx) as Index[str, ctx];
                        mut ptr := &ctx[brand] as *str;
                        *ptr = std.Clone(ctx, arg.Struct.struct_name);
                    }
                }
                j = j + 1;
            }

            mut existing := (*env).struct_registry.Get(concrete_name);
            if existing.Ok == 0 {
                mut placeholder: StructLayout[ctx];
                placeholder.brand = brand;
                placeholder.fields = std.HashMapNew(ctx);
                (*env).struct_registry.Insert(std.Clone(ctx, concrete_name), placeholder);

                mut concrete_fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
                mut fields_vec := &ctx[template.fields] as *std.Vector[ast.FieldDef[ctx], ctx];
                mut f_idx := 0;
                while f_idx < len(*fields_vec) {
                    mut field := (*fields_vec)[f_idx];
                    mut substituted_type := substitute_generics(env, field.field_type, substitution_map, ctx);
                    mut resolved_field_type := env_resolve_type(env, substituted_type, ctx);
                    concrete_fields.Insert(std.Clone(ctx, field.name), resolved_field_type);
                    f_idx = f_idx + 1;
                }

                placeholder.fields = concrete_fields;
                (*env).struct_registry.Insert(std.Clone(ctx, concrete_name), placeholder);

                mut success_msg := std.Format("monomorphize_impl: successfully instantiated struct '%s'", concrete_name);
                typechecker_log_trace("🔄", success_msg, ctx);

                // Ephemeral view checking for unbranded monomorphization
                if brand == empty[Index[str, ctx]] {
                    mut f := 0;
                    while f < len(*fields_vec) {
                        mut field := (*fields_vec)[f];
                        mut lookup := concrete_fields.Get(field.name);
                        if lookup.Ok {
                            mut field_type := lookup.Val;
                            if env_type_is_ephemeral_view(field_type, ctx) == 1 {
                                mut err: Index[errors.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
                                ctx[err].kind.tag = 2; // TypeError
                                mut msg := std.Concat("Semantic Error: Unbranded monomorphized struct '", concrete_name);
                                msg = std.Concat(msg, "' cannot contain ephemeral slice or view field '");
                                msg = std.Concat(msg, field.name);
                                msg = std.Concat(msg, "'");
                                ctx[err].message = std.Clone(ctx, msg);
                                res.tag = 1; // Err
                                res.Err.error = err;
                                return res;
                            }
                        }
                        f = f + 1;
                    }
                }
            }

            res.Ok.val.tag = 8; // Struct
            res.Ok.val.Struct.struct_name = std.Clone(ctx, concrete_name);
            res.Ok.val.Struct.brand = brand;
            return res;
        }

        mut err: Index[errors.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[err].kind.tag = 2; // TypeError
        ctx[err].message = std.Clone(ctx, std.Concat("Semantic Error: Generic template not found: ", template_name));
        res.tag = 1; // Err
        res.Err.error = err;
        return res;
    }
}

func env_register_std_templates(env: *TypeEnvironment[ctx], ctx: &Arena) {
    unsafe {
        mut t_int := make_type_int();
        mut t_byte := make_type_byte();
        mut t_bool := make_type_bool();
        mut t_arena := make_type_arena();
        mut t_str := make_type_str();
        mut t_arena_ptr := make_type_pointer(t_arena, ctx);

        // 1. Vector[T, ctx]
        mut vec_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        vec_gen.Push(std.Clone(ctx, "T"));
        vec_gen.Push(std.Clone(ctx, "ctx"));

        mut vec_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        vec_fields.Push(make_field("data", make_type_pointer(make_type_struct("T", "", ctx), ctx), ctx));
        vec_fields.Push(make_field("len", t_int, ctx));
        vec_fields.Push(make_field("capacity", t_int, ctx));
        vec_fields.Push(make_field("arena", t_arena_ptr, ctx));

        mut vec_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut vec_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[vec_gen_idx] = vec_gen;
        ctx[vec_fields_idx] = vec_fields;

        mut vec_tmpl: StructTemplate[ctx];
        vec_tmpl.generics = vec_gen_idx;
        vec_tmpl.fields = vec_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Vector"), vec_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Vector"), vec_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Vector"), vec_tmpl);

        // 2. HashMap[K, V, ctx]
        mut map_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        map_gen.Push(std.Clone(ctx, "K"));
        map_gen.Push(std.Clone(ctx, "V"));
        map_gen.Push(std.Clone(ctx, "ctx"));

        mut map_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        map_fields.Push(make_field("keys", make_type_pointer(make_type_struct("K", "", ctx), ctx), ctx));
        map_fields.Push(make_field("values", make_type_pointer(make_type_struct("V", "", ctx), ctx), ctx));
        map_fields.Push(make_field("occupied", make_type_pointer(t_int, ctx), ctx));
        map_fields.Push(make_field("len", t_int, ctx));
        map_fields.Push(make_field("capacity", t_int, ctx));
        map_fields.Push(make_field("arena", t_arena_ptr, ctx));

        mut map_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut map_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[map_gen_idx] = map_gen;
        ctx[map_fields_idx] = map_fields;

        mut map_tmpl: StructTemplate[ctx];
        map_tmpl.generics = map_gen_idx;
        map_tmpl.fields = map_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_HashMap"), map_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.HashMap"), map_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "HashMap"), map_tmpl);

        // 3. Pool[T, ctx]
        mut pool_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        pool_gen.Push(std.Clone(ctx, "T"));
        pool_gen.Push(std.Clone(ctx, "ctx"));

        mut pool_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        pool_fields.Push(make_field("data", make_type_pointer(make_type_struct("T", "", ctx), ctx), ctx));
        pool_fields.Push(make_field("occupied", make_type_pointer(t_int, ctx), ctx));
        pool_fields.Push(make_field("free_list", make_type_pointer(t_int, ctx), ctx));
        pool_fields.Push(make_field("len", t_int, ctx));
        pool_fields.Push(make_field("capacity", t_int, ctx));
        pool_fields.Push(make_field("free_len", t_int, ctx));
        pool_fields.Push(make_field("arena", t_arena_ptr, ctx));

        mut pool_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut pool_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[pool_gen_idx] = pool_gen;
        ctx[pool_fields_idx] = pool_fields;

        mut pool_tmpl: StructTemplate[ctx];
        pool_tmpl.generics = pool_gen_idx;
        pool_tmpl.fields = pool_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Pool"), pool_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Pool"), pool_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Pool"), pool_tmpl);

        // 4. RcNode[T]
        mut rcnode_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        rcnode_gen.Push(std.Clone(ctx, "T"));

        mut rcnode_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        rcnode_fields.Push(make_field("value", make_type_struct("T", "", ctx), ctx));
        rcnode_fields.Push(make_field("ref_count", t_int, ctx));

        mut rcnode_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut rcnode_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[rcnode_gen_idx] = rcnode_gen;
        ctx[rcnode_fields_idx] = rcnode_fields;

        mut rcnode_tmpl: StructTemplate[ctx];
        rcnode_tmpl.generics = rcnode_gen_idx;
        rcnode_tmpl.fields = rcnode_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_RcNode"), rcnode_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.RcNode"), rcnode_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "RcNode"), rcnode_tmpl);

        // 5. Rc[T, ctx]
        mut rc_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        rc_gen.Push(std.Clone(ctx, "T"));
        rc_gen.Push(std.Clone(ctx, "ctx"));

        mut rc_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        rc_fields.Push(make_field("node_index", make_type_index("std_RcNode_T", "ctx", ctx), ctx));

        mut pool_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
        pool_args.Push(make_type_struct("std_RcNode_T", "", ctx));
        pool_args.Push(make_type_struct("ctx", "", ctx));
        rc_fields.Push(make_field("pool", make_type_pointer(make_type_generic("std.Pool", pool_args, ctx), ctx), ctx));

        mut rc_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut rc_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[rc_gen_idx] = rc_gen;
        ctx[rc_fields_idx] = rc_fields;

        mut rc_tmpl: StructTemplate[ctx];
        rc_tmpl.generics = rc_gen_idx;
        rc_tmpl.fields = rc_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Rc"), rc_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Rc"), rc_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Rc"), rc_tmpl);

        // 6. GraphNode[T, ctx]
        mut gnode_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        gnode_gen.Push(std.Clone(ctx, "T"));
        gnode_gen.Push(std.Clone(ctx, "ctx"));

        mut gnode_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        gnode_fields.Push(make_field("value", make_type_struct("T", "", ctx), ctx));

        mut vec_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
        vec_args.Push(t_int);
        vec_args.Push(make_type_struct("ctx", "", ctx));
        gnode_fields.Push(make_field("edges", make_type_generic("std.Vector", vec_args, ctx), ctx));

        mut gnode_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut gnode_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[gnode_gen_idx] = gnode_gen;
        ctx[gnode_fields_idx] = gnode_fields;

        mut gnode_tmpl: StructTemplate[ctx];
        gnode_tmpl.generics = gnode_gen_idx;
        gnode_tmpl.fields = gnode_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_GraphNode"), gnode_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.GraphNode"), gnode_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "GraphNode"), gnode_tmpl);

        // 7. Graph[T, ctx]
        mut graph_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        graph_gen.Push(std.Clone(ctx, "T"));
        graph_gen.Push(std.Clone(ctx, "ctx"));

        mut graph_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);

        mut pool_args_g: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
        pool_args_g.Push(make_type_struct("std_GraphNode_T_ctx", "", ctx));
        pool_args_g.Push(make_type_struct("ctx", "", ctx));
        graph_fields.Push(make_field("nodes", make_type_generic("std.Pool", pool_args_g, ctx), ctx));

        mut graph_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut graph_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[graph_gen_idx] = graph_gen;
        ctx[graph_fields_idx] = graph_fields;

        mut graph_tmpl: StructTemplate[ctx];
        graph_tmpl.generics = graph_gen_idx;
        graph_tmpl.fields = graph_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Graph"), graph_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Graph"), graph_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Graph"), graph_tmpl);

        // 8. Mutex[T, ctx]
        mut mutex_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        mutex_gen.Push(std.Clone(ctx, "T"));
        mutex_gen.Push(std.Clone(ctx, "ctx"));

        mut mutex_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        mutex_fields.Push(make_field("value", make_type_struct("T", "", ctx), ctx));
        mutex_fields.Push(make_field("lock_state", t_int, ctx));

        mut mutex_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut mutex_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[mutex_gen_idx] = mutex_gen;
        ctx[mutex_fields_idx] = mutex_fields;

        mut mutex_tmpl: StructTemplate[ctx];
        mutex_tmpl.generics = mutex_gen_idx;
        mutex_tmpl.fields = mutex_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Mutex"), mutex_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Mutex"), mutex_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Mutex"), mutex_tmpl);

        // 9. Channel[T, ctx]
        mut chan_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        chan_gen.Push(std.Clone(ctx, "T"));
        chan_gen.Push(std.Clone(ctx, "ctx"));

        mut chan_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        chan_fields.Push(make_field("capacity", t_int, ctx));
        chan_fields.Push(make_field("len", t_int, ctx));
        chan_fields.Push(make_field("_phantom", make_type_pointer(make_type_struct("T", "", ctx), ctx), ctx));

        mut chan_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut chan_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[chan_gen_idx] = chan_gen;
        ctx[chan_fields_idx] = chan_fields;

        mut chan_tmpl: StructTemplate[ctx];
        chan_tmpl.generics = chan_gen_idx;
        chan_tmpl.fields = chan_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_Channel"), chan_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.Channel"), chan_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "Channel"), chan_tmpl);

        // 10. GenerationalArena[T, ctx]
        mut gena_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        gena_gen.Push(std.Clone(ctx, "T"));
        gena_gen.Push(std.Clone(ctx, "ctx"));

        mut gena_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        gena_fields.Push(make_field("current_ctx", t_arena, ctx));
        gena_fields.Push(make_field("next_ctx", t_arena, ctx));
        gena_fields.Push(make_field("survivor", make_type_index("T", "current_ctx", ctx), ctx));

        mut gena_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut gena_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[gena_gen_idx] = gena_gen;
        ctx[gena_fields_idx] = gena_fields;

        mut gena_tmpl: StructTemplate[ctx];
        gena_tmpl.generics = gena_gen_idx;
        gena_tmpl.fields = gena_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_GenerationalArena"), gena_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.GenerationalArena"), gena_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "GenerationalArena"), gena_tmpl);

        // 11. os.Dir[ctx]
        mut dir_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        dir_gen.Push(std.Clone(ctx, "ctx"));

        mut dir_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        dir_fields.Push(make_field("handle", make_type_pointer(t_byte, ctx), ctx));

        mut dir_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut dir_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[dir_gen_idx] = dir_gen;
        ctx[dir_fields_idx] = dir_fields;

        mut dir_tmpl: StructTemplate[ctx];
        dir_tmpl.generics = dir_gen_idx;
        dir_tmpl.fields = dir_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "os_Dir"), dir_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "os.Dir"), dir_tmpl);

        // 12. os.DirEntry[ctx]
        mut dire_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        dire_gen.Push(std.Clone(ctx, "ctx"));

        mut dire_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        dire_fields.Push(make_field("name", t_str, ctx));
        dire_fields.Push(make_field("is_dir", t_int, ctx));

        mut dire_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut dire_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[dire_gen_idx] = dire_gen;
        ctx[dire_fields_idx] = dire_fields;

        mut dire_tmpl: StructTemplate[ctx];
        dire_tmpl.generics = dire_gen_idx;
        dire_tmpl.fields = dire_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "os_DirEntry"), dire_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "os.DirEntry"), dire_tmpl);

        // 13. ThreadLocalContext[ctx]
        mut tlc_gen: std.Vector[str, ctx] := std.VectorNew(ctx);
        tlc_gen.Push(std.Clone(ctx, "ctx"));

        mut tlc_fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
        tlc_fields.Push(make_field("arena", make_type_pointer(t_arena, ctx), ctx));
        tlc_fields.Push(make_field("_phantom", make_type_pointer(make_type_struct("ctx", "", ctx), ctx), ctx));

        mut tlc_gen_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut tlc_fields_idx: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[tlc_gen_idx] = tlc_gen;
        ctx[tlc_fields_idx] = tlc_fields;

        mut tlc_tmpl: StructTemplate[ctx];
        tlc_tmpl.generics = tlc_gen_idx;
        tlc_tmpl.fields = tlc_fields_idx;

        (*env).struct_templates.Insert(std.Clone(ctx, "std_ThreadLocalContext"), tlc_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "std.ThreadLocalContext"), tlc_tmpl);
        (*env).struct_templates.Insert(std.Clone(ctx, "ThreadLocalContext"), tlc_tmpl);
    }
}


func env_register_std_structs(env: *TypeEnvironment[ctx], ctx: &Arena) {
    unsafe {
        mut t_int := make_type_int();

        // 1. APIRequest
        mut api_layout: StructLayout[ctx];
        api_layout.brand = empty[Index[str, ctx]];
        api_layout.fields = std.HashMapNew(ctx);
        api_layout.fields.Insert("UserID", t_int);
        api_layout.fields.Insert("SessionID", t_int);
        api_layout.fields.Insert("Active", t_int);
        env_register_struct(env, "APIRequest", api_layout, ctx);

        // 2. SessionNode [connCtx]
        mut session_layout: StructLayout[ctx];
        mut brand_idx: Index[str, ctx] := os.ArenaAlloc(ctx) as Index[str, ctx];
        mut brand_ptr := &ctx[brand_idx] as *str;
        *brand_ptr = "connCtx";
        session_layout.brand = brand_idx;
        session_layout.fields = std.HashMapNew(ctx);
        session_layout.fields.Insert("SessionID", t_int);
        session_layout.fields.Insert("Next", make_type_index("SessionNode", "connCtx", ctx));
        env_register_struct(env, "SessionNode", session_layout, ctx);
    }
}

func register_fn(env: *TypeEnvironment[ctx], name: str, params: std.Vector[ast.Type[ctx], ctx], ret_t: ast.Type[ctx], ctx: &Arena) {
    unsafe {
        mut sig: FunctionSignature[ctx];
        sig.params = params;
        sig.return_type = ret_t;
        sig.return_origins = set_init(ctx);
        
        mut param_names: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut i := 0;
        while i < len(params) {
            param_names.Push(std.Concat("arg", std.FormatInt(i)));
            i = i + 1;
        }
        sig.param_names = param_names;
        
        env_register_function(env, name, sig, ctx);
    }
}

 func env_register_std_functions(env: *TypeEnvironment[ctx], ctx: &Arena) {
        unsafe {
            mut t_int := make_type_int();
            mut t_byte := make_type_byte();
            mut t_bool := make_type_bool();
            mut t_arena := make_type_arena();
            mut t_str := make_type_str();
            mut t_void: ast.Type[ctx]; t_void.tag = 3; // Void
            mut t_arena_ptr := make_type_pointer(t_arena, ctx);
            mut t_any_idx := make_type_index("Any", "", ctx);

            // --- Standard FFI Argument Vector Configurations ---

            mut p_void: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            mut p_int: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_int.Push(t_int);
            mut p_str: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_str.Push(t_str);
            mut p_byte: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_byte.Push(t_byte);

            mut p_arena_ptr: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_arena_ptr.Push(t_arena_ptr);

            mut p_arena_ptr_arena_ptr: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_arena_ptr_arena_ptr.Push(t_arena_ptr);
            p_arena_ptr_arena_ptr.Push(t_arena_ptr);

            mut p_arena_ptr_str: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_arena_ptr_str.Push(t_arena_ptr);
            p_arena_ptr_str.Push(t_str);

            mut p_str_str: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_str_str.Push(t_str);
            p_str_str.Push(t_str);

            mut p_str_int: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_str_int.Push(t_str);
            p_str_int.Push(t_int);

            mut p_str_int_int: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_str_int_int.Push(t_str);
            p_str_int_int.Push(t_int);
            p_str_int_int.Push(t_int);

            mut p_str_str_arena_ptr: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_str_str_arena_ptr.Push(t_str);
            p_str_str_arena_ptr.Push(t_str);
            p_str_str_arena_ptr.Push(t_arena_ptr);

            mut p_dir: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_dir.Push(make_type_struct("os_Dir_ctx", "ctx", ctx));

            mut p_arena_ptr_dir: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_arena_ptr_dir.Push(t_arena_ptr);
            p_arena_ptr_dir.Push(make_type_struct("os_Dir_ctx", "ctx", ctx));

            mut p_arena_ptr_any: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            p_arena_ptr_any.Push(t_arena_ptr);
            p_arena_ptr_any.Push(t_any_idx);

            // Vector generic helper for return type signatures
            mut vec_args_str: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            vec_args_str.Push(t_str);
            vec_args_str.Push(make_type_struct("ctx", "", ctx));

            // --- FFI Registration Mapping ---

            register_fn(env, "os.ScratchReset", p_void, t_void, ctx);
            register_fn(env, "os_ScratchReset", p_void, t_void, ctx);
            register_fn(env, "std.Yield", p_void, t_void, ctx);
            register_fn(env, "std_Yield", p_void, t_void, ctx);

            // os.Arena.New
            mut sig_arena_new: FunctionSignature[ctx];
            mut arena_new_names: std.Vector[str, ctx] := std.VectorNew(ctx);
            mut arena_new_params: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            sig_arena_new.param_names = arena_new_names;
            sig_arena_new.params = arena_new_params;
            sig_arena_new.return_type = t_arena;
            sig_arena_new.return_origins = set_init(ctx);
            env_register_function(env, "os_Arena_New", sig_arena_new, ctx);
            env_register_function(env, "os.Arena.New", sig_arena_new, ctx);
            env_register_function(env, "os_Arena.New", sig_arena_new, ctx);

            register_fn(env, "os.GetThreadScratch", p_void, make_type_struct("std_ThreadLocalContext_Any", "Any", ctx), ctx);
            register_fn(env, "os_GetThreadScratch", p_void, make_type_struct("std_ThreadLocalContext_Any", "Any", ctx), ctx);

            register_fn(env, "os.Args", p_arena_ptr, make_type_generic("std.Vector", vec_args_str, ctx), ctx);
            register_fn(env, "os_Args", p_arena_ptr, make_type_generic("std.Vector", vec_args_str, ctx), ctx);
            register_fn(env, "os.ArenaValidate", p_arena_ptr, t_void, ctx);
            register_fn(env, "os_ArenaValidate", p_arena_ptr, t_void, ctx);
            register_fn(env, "os.SetThreadScratch", p_arena_ptr, t_void, ctx);
            register_fn(env, "os_SetThreadScratch", p_arena_ptr, t_void, ctx);

            register_fn(env, "os.VectorNew", p_arena_ptr, make_type_struct("std_Vector_Any", "ctx", ctx), ctx);
            register_fn(env, "os_VectorNew", p_arena_ptr, make_type_struct("std_Vector_Any", "ctx", ctx), ctx);
            register_fn(env, "std.VectorNew", p_arena_ptr, make_type_struct("std_Vector_Any", "ctx", ctx), ctx);
            register_fn(env, "std_VectorNew", p_arena_ptr, make_type_struct("std_Vector_Any", "ctx", ctx), ctx);

            register_fn(env, "os.HashMapNew", p_arena_ptr, make_type_struct("std_HashMap_Any", "ctx", ctx), ctx);
            register_fn(env, "os_HashMapNew", p_arena_ptr, make_type_struct("std_HashMap_Any", "ctx", ctx), ctx);
            register_fn(env, "std.HashMapNew", p_arena_ptr, make_type_struct("std_HashMap_Any", "ctx", ctx), ctx);
            register_fn(env, "std_HashMapNew", p_arena_ptr, make_type_struct("std_HashMap_Any", "ctx", ctx), ctx);

            register_fn(env, "os.PoolNew", p_arena_ptr, make_type_struct("std_Pool_Any", "ctx", ctx), ctx);
            register_fn(env, "os_PoolNew", p_arena_ptr, make_type_struct("std_Pool_Any", "ctx", ctx), ctx);
            register_fn(env, "std.PoolNew", p_arena_ptr, make_type_struct("std_Pool_Any", "ctx", ctx), ctx);
            register_fn(env, "std_PoolNew", p_arena_ptr, make_type_struct("std_Pool_Any", "ctx", ctx), ctx);

            register_fn(env, "std.MutexNew", p_arena_ptr, make_type_struct("std_Mutex_Any", "ctx", ctx), ctx);
            register_fn(env, "std_MutexNew", p_arena_ptr, make_type_struct("std_Mutex_Any", "ctx", ctx), ctx);
            register_fn(env, "std.ChannelNew", p_arena_ptr, make_type_struct("std_Channel_Any", "ctx", ctx), ctx);
            register_fn(env, "std_ChannelNew", p_arena_ptr, make_type_struct("std_Channel_Any", "ctx", ctx), ctx);

            register_fn(env, "os.Exit", p_int, t_void, ctx);
            register_fn(env, "os_Exit", p_int, t_void, ctx);
            register_fn(env, "os.ScratchAlloc", p_int, make_type_pointer(t_byte, ctx), ctx);
            register_fn(env, "os_ScratchAlloc", p_int, make_type_pointer(t_byte, ctx), ctx);
            register_fn(env, "std.FormatInt", p_int, t_str, ctx);
            register_fn(env, "std_FormatInt", p_int, t_str, ctx);

            register_fn(env, "std.Format", p_str, t_str, ctx);
            register_fn(env, "std_Format", p_str, t_str, ctx);
            register_fn(env, "std.parse_int", p_str, t_int, ctx);
            register_fn(env, "std_parse_int", p_str, t_int, ctx);
            register_fn(env, "std.str_trim", p_str, t_str, ctx);
            register_fn(env, "std_str_trim", p_str, t_str, ctx);

            register_fn(env, "std.is_alpha", p_byte, t_bool, ctx);
            register_fn(env, "std_is_alpha", p_byte, t_bool, ctx);
            register_fn(env, "std.is_digit", p_byte, t_bool, ctx);
            register_fn(env, "std_is_digit", p_byte, t_bool, ctx);
            register_fn(env, "std.is_whitespace", p_byte, t_bool, ctx);
            register_fn(env, "std_is_whitespace", p_byte, t_bool, ctx);

            register_fn(env, "std.GenerationalSwap", p_arena_ptr_arena_ptr, t_void, ctx);
            register_fn(env, "std_GenerationalSwap", p_arena_ptr_arena_ptr, t_void, ctx);

            register_fn(env, "os.OpenDir", p_arena_ptr_str, make_type_struct("LookupResult_os_Dir_ctx", "ctx", ctx), ctx);
            register_fn(env, "os_OpenDir", p_arena_ptr_str, make_type_struct("LookupResult_os_Dir_ctx", "ctx", ctx), ctx);
            register_fn(env, "os.ReadFile", p_arena_ptr_str, t_str, ctx);
            register_fn(env, "os_ReadFile", p_arena_ptr_str, t_str, ctx);

            register_fn(env, "std.Concat", p_str_str, t_str, ctx);
            register_fn(env, "std_Concat", p_str_str, t_str, ctx);
            register_fn(env, "std.str_eq", p_str_str, t_int, ctx);
            register_fn(env, "std_str_eq", p_str_str, t_int, ctx);
            register_fn(env, "std.str_find", p_str_str, t_int, ctx);
            register_fn(env, "std_str_find", p_str_str, t_int, ctx);
            register_fn(env, "os.WriteFile", p_str_str, t_int, ctx);
            register_fn(env, "os_WriteFile", p_str_str, t_int, ctx);

            register_fn(env, "std.str_byte_at", p_str_int, t_byte, ctx);
            register_fn(env, "std_str_byte_at", p_str_int, t_byte, ctx);

            register_fn(env, "std.str_slice", p_str_int_int, t_str, ctx);
            register_fn(env, "std_str_slice", p_str_int_int, t_str, ctx);

            register_fn(env, "os.path_join", p_str_str_arena_ptr, t_str, ctx);
            register_fn(env, "os_path_join", p_str_str_arena_ptr, t_str, ctx);
            register_fn(env, "std.str_split", p_str_str_arena_ptr, make_type_generic("std.Vector", vec_args_str, ctx), ctx);
            register_fn(env, "std_str_split", p_str_str_arena_ptr, make_type_generic("std.Vector", vec_args_str, ctx), ctx);

            register_fn(env, "os.CloseDir", p_dir, t_void, ctx);
            register_fn(env, "os_CloseDir", p_dir, t_void, ctx);

            register_fn(env, "os.ReadDir", p_arena_ptr_dir, make_type_struct("LookupResult_os_DirEntry_ctx", "ctx", ctx), ctx);
            register_fn(env, "os_ReadDir", p_arena_ptr_dir, make_type_struct("LookupResult_os_DirEntry_ctx", "ctx", ctx), ctx);

            register_fn(env, "std.Clone", p_arena_ptr_any, t_any_idx, ctx);
            register_fn(env, "std_Clone", p_arena_ptr_any, t_any_idx, ctx);
        }
    }

func env_new(ctx: &Arena) TypeEnvironment[ctx] { 
    mut env_idx: Index[TypeEnvironment[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe { 
        ctx[env_idx].struct_registry = std.HashMapNew(ctx);
        ctx[env_idx].struct_templates = std.HashMapNew(ctx);
        ctx[env_idx].enum_templates = std.HashMapNew(ctx);
        ctx[env_idx].function_registry = std.HashMapNew(ctx);
        ctx[env_idx].variable_types = std.HashMapNew(ctx);
        ctx[env_idx].resolved_types = std.HashMapNew(ctx);
        ctx[env_idx].enum_registry = std.HashMapNew(ctx);
        ctx[env_idx].current_prefix = "";
        ctx[env_idx].imports = std.HashMapNew(ctx);
        ctx[env_idx].imports.Insert(std.Clone(ctx, "std"), std.Clone(ctx, "std_"));
        ctx[env_idx].imports.Insert(std.Clone(ctx, "os"), std.Clone(ctx, "os_"));
        ctx[env_idx].variable_origins = std.HashMapNew(ctx);
        ctx[env_idx].moved_vars = std.HashMapNew(ctx);
        ctx[env_idx].open_directories = std.HashMapNew(ctx);
        ctx[env_idx].errors = std.VectorNew(ctx);
        ctx[env_idx].expected_return_type = empty[Index[ast.Type[ctx], ctx]];
        ctx[env_idx].current_function_return_origins = empty[Index[OriginSet[ctx], ctx]];
        ctx[env_idx].current_function_inout_params = empty[Index[std.Vector[str, ctx], ctx]];
        ctx[env_idx].current_function_local_vars = empty[Index[OriginSet[ctx], ctx]];
        ctx[env_idx].checked_results = std.HashMapNew(ctx);
        ctx[env_idx].in_unsafe_block = 0;

        env_register_std_templates(&ctx[env_idx] as *TypeEnvironment[ctx], ctx);
        env_register_std_structs(&ctx[env_idx] as *TypeEnvironment[ctx], ctx);
        env_register_std_functions(&ctx[env_idx] as *TypeEnvironment[ctx], ctx);

        return ctx[env_idx];
    }
}




func env_resolve_namespaced_ident(env: *TypeEnvironment[ctx], name: str, ctx: &Arena) str {
    // 1. Handle LookupResult_ and CastResult_ prefixes
    if len(name) >= 13 && std.str_eq(std.str_slice(name, 0, 13), "LookupResult_") {
        mut suffix := std.str_slice(name, 13, len(name));
        mut resolved := env_resolve_namespaced_ident(env, suffix, ctx);
        return std.Clone(ctx, std.Concat("LookupResult_", resolved));
    }
    if len(name) >= 11 && std.str_eq(std.str_slice(name, 0, 11), "CastResult_") {
        mut suffix := std.str_slice(name, 11, len(name));
        mut resolved := env_resolve_namespaced_ident(env, suffix, ctx);
        return std.Clone(ctx, std.Concat("CastResult_", resolved));
    }

    // 2. Handle dot-separated namespaced alias (e.g. lib.Helper)
    mut dot_idx := std.str_find(name, ".");
    if dot_idx != 0 - 1 {
        mut alias := std.str_slice(name, 0, dot_idx);
        mut rest := std.str_slice(name, dot_idx + 1, len(name));
        unsafe {
            mut lookup := (*env).imports.Get(alias);
            if lookup.Ok {
                return std.Clone(ctx, std.Concat(lookup.Val, rest));
            }
        }
        return name;
    }

    // 3. Primitives & already namespaced types
    if std.str_eq(name, "int") || std.str_eq(name, "byte") || std.str_eq(name, "bool") ||
       std.str_eq(name, "str") || std.str_eq(name, "Arena") || std.str_eq(name, "void") ||
       std.str_eq(name, "Any") {
        return name;
    }

    if std.str_find(name, "__") != 0 - 1 || 
       (len(name) >= 4 && std.str_eq(std.str_slice(name, 0, 4), "std_")) ||
       (len(name) >= 3 && std.str_eq(std.str_slice(name, 0, 3), "os_")) {
        return name;
    }

    // 4. Default prefixing
    unsafe {
        return std.Clone(ctx, std.Concat((*env).current_prefix, name));
    }
}

func env_register_struct(env: *TypeEnvironment[ctx], name: str, layout: StructLayout[ctx], ctx: &Arena) {
    unsafe {
        (*env).struct_registry.Insert(std.Clone(ctx, name), layout);
    }
    mut msg := std.Format("env_register_struct: registered struct '%s' with %d fields", name, layout.fields.len);
    typechecker_log_trace("🗄️", msg, ctx);
}

func env_register_function(env: *TypeEnvironment[ctx], name: str, sig: FunctionSignature[ctx], ctx: &Arena) {
    unsafe {
        (*env).function_registry.Insert(std.Clone(ctx, name), sig);
    }
    mut msg := std.Format("env_register_function: registered function '%s' with %d parameters", name, sig.params.len);
    typechecker_log_trace("🗄️", msg, ctx);
}

func typechecker_get_file_stem(path: str, ctx: &Arena) str {
    mut last_slash := 0 - 1;
    mut dot_idx := 0 - 1;
    mut i := 0;
    while i < len(path) {
        mut b := std.str_byte_at(path, i);
        if b == 47 { // '/'
            last_slash = i;
        }
        if b == 92 { // '\\'
            last_slash = i;
        }
        if b == 46 { // '.'
            dot_idx = i;
        }
        i = i + 1;
    }
    mut start := last_slash + 1;
    mut end := len(path);
    if dot_idx > start {
        end = dot_idx;
    }
    return std.Clone(ctx, std.str_slice(path, start, end));
}

func env_resolve_type(env: *TypeEnvironment[ctx], t: ast.Type[ctx], ctx: &Arena) ast.Type[ctx] {
    mut res_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[res_idx] = t;
        if t.tag == 7 { // Index
            ctx[res_idx].Index.struct_name = env_resolve_namespaced_ident(env, t.Index.struct_name, ctx);
            
            mut brand_name := "";
            if t.Index.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                brand_name = *brand_str_ptr;
            }
            mut temp_struct := make_type_struct(t.Index.struct_name, brand_name, ctx);
            mut resolved_inner := env_resolve_type(env, temp_struct, ctx);
            if resolved_inner.tag == 8 { // Struct
                ctx[res_idx].Index.struct_name = std.Clone(ctx, resolved_inner.Struct.struct_name);
            }
        } else {
            if t.tag == 8 { // Struct
                mut namespaced_name := env_resolve_namespaced_ident(env, t.Struct.struct_name, ctx);
                ctx[res_idx].Struct.struct_name = namespaced_name;
                
                if t.Struct.brand != empty[Index[str, ctx]] {
                    mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                    mut brand_name := *brand_str_ptr;
                    
                    mut has_template := 0;
                    if (*env).struct_templates.Get(namespaced_name).Ok {
                        has_template = 1;
                    } else {
                        if (*env).enum_templates.Get(namespaced_name).Ok {
                            has_template = 1;
                        }
                    }
                    
                    if has_template == 1 {
                        mut args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
                        args.Push(make_type_struct(brand_name, "", ctx));
                        
                        mut mono_res := monomorphize(env, namespaced_name, args, ctx);
                        if mono_res.tag == 0 { // Ok
                            return mono_res.Ok.val;
                        } else {
                            (*env).errors.Push(ctx[mono_res.Err.error]);
                        }
                    }
                }
            } else {
                if t.tag == 9 { // RawPointer
                    mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx); 
                    ctx[inner_idx] = env_resolve_type(env, ctx[t.RawPointer.inner], ctx);
                    ctx[res_idx].RawPointer.inner = inner_idx;
                } else {
                    if t.tag == 6 { // Slice
                        mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                        ctx[inner_idx] = env_resolve_type(env, ctx[t.Slice.inner], ctx);
                        ctx[res_idx].Slice.inner = inner_idx;
                    } else {
                        if t.tag == 10 { // Generic
                            mut name := env_resolve_namespaced_ident(env, t.Generic.name, ctx);
                            mut args_vec := &ctx[t.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
                            mut new_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
                            mut i := 0;
                            while i < len(*args_vec) {
                                mut arg := (*args_vec)[i];
                                new_args.Push(env_resolve_type(env, arg, ctx));
                                i = i + 1;
                            }
                            
                            mut mono_res := monomorphize(env, name, new_args, ctx);
                            if mono_res.tag == 0 { // Ok
                                return mono_res.Ok.val;
                            } else {
                                (*env).errors.Push(ctx[mono_res.Err.error]);
                                mut dummy: ast.Type[ctx];
                                dummy.tag = 3; // Void
                                return dummy;
                            }
                        }
                    } 
                }
            }
        }
        return ctx[res_idx];
    }
}

func env_pre_register_statement(env: *TypeEnvironment[ctx], stmt: ast.Statement[ctx], ctx: &Arena) {
    if stmt.tag == 0 { // Import
        mut path := stmt.Import.path;
        mut alias := stmt.Import.alias;
        mut stem := typechecker_get_file_stem(path, ctx);
        mut prefix := std.Concat(stem, "__");
        mut alias_name := alias;
        if std.str_eq(alias_name, "") {
            alias_name = stem;
        }
        unsafe {
            (*env).imports.Insert(std.Clone(ctx, alias_name), std.Clone(ctx, prefix));
        }
    }
    if stmt.tag == 1 { // StructDecl
        mut name := stmt.StructDecl.name;
        mut namespaced_name := env_resolve_namespaced_ident(env, name, ctx);
        
        mut is_generic := 0;
        unsafe {
            if stmt.StructDecl.generics != empty[Index[std.Vector[str, ctx], ctx]] {
                mut generics_vec := &ctx[stmt.StructDecl.generics] as *std.Vector[str, ctx];
                if len(*generics_vec) > 0 {
                    is_generic = 1;
                }
            }
        }

        if is_generic == 1 {
            unsafe {
                mut template: StructTemplate[ctx];
                template.generics = stmt.StructDecl.generics;
                template.fields = stmt.StructDecl.fields;
                (*env).struct_templates.Insert(std.Clone(ctx, namespaced_name), template);
            }
        } else {
            mut layout: StructLayout[ctx];
            layout.brand = empty[Index[str, ctx]];
            layout.fields = std.HashMapNew(ctx);

            unsafe {
                mut fields_vec := &ctx[stmt.StructDecl.fields] as *std.Vector[ast.FieldDef[ctx], ctx];
                mut i := 0;
                while i < len(*fields_vec) {
                    mut f := (*fields_vec)[i];
                    mut resolved_t := env_resolve_type(env, f.field_type, ctx);
                    layout.fields.Insert(std.Clone(ctx, f.name), resolved_t);
                    i = i + 1;
                }
            }
            env_register_struct(env, namespaced_name, layout, ctx);
        }
    }
    if stmt.tag == 2 { // EnumDecl
        mut name := stmt.EnumDecl.name;
        mut namespaced_name := env_resolve_namespaced_ident(env, name, ctx);

        mut is_generic := 0;
        unsafe {
            if stmt.EnumDecl.generics != empty[Index[std.Vector[str, ctx], ctx]] {
                mut generics_vec := &ctx[stmt.EnumDecl.generics] as *std.Vector[str, ctx];
                if len(*generics_vec) > 0 {
                    is_generic = 1;
                }
            }
        }

        if is_generic == 1 {
            unsafe {
                mut template: EnumTemplate[ctx];
                template.generics = stmt.EnumDecl.generics;
                template.variants = stmt.EnumDecl.variants;
                (*env).enum_templates.Insert(std.Clone(ctx, namespaced_name), template);
            }
        } else {
            mut enum_layout: StructLayout[ctx];
            enum_layout.brand = empty[Index[str, ctx]];
            enum_layout.fields = std.HashMapNew(ctx);

            mut t_int: ast.Type[ctx];
            t_int.tag = 0; // Int
            enum_layout.fields.Insert(std.Clone(ctx, "tag"), t_int);

            mut variants_list: std.Vector[str, ctx] := std.VectorNew(ctx);
            unsafe {
                mut variants_vec := &ctx[stmt.EnumDecl.variants] as *std.Vector[ast.VariantDef[ctx], ctx];
                mut i := 0;
                while i < len(*variants_vec) {
                    mut v := (*variants_vec)[i];
                    variants_list.Push(std.Clone(ctx, v.name));
                    mut variant_struct_name := std.Concat(namespaced_name, "_");
                    variant_struct_name = std.Concat(variant_struct_name, v.name);

                    mut variant_layout: StructLayout[ctx];
                    variant_layout.brand = empty[Index[str, ctx]];
                    variant_layout.fields = std.HashMapNew(ctx);

                    mut fields_vec := &ctx[v.fields] as *std.Vector[ast.FieldDef[ctx], ctx];
                    mut j := 0;
                    while j < len(*fields_vec) {
                        mut f := (*fields_vec)[j];
                        mut resolved_t := env_resolve_type(env, f.field_type, ctx);
                        variant_layout.fields.Insert(std.Clone(ctx, f.name), resolved_t);
                        j = j + 1;
                    }

                    env_register_struct(env, variant_struct_name, variant_layout, ctx);

                    mut t_variant: ast.Type[ctx];
                    t_variant.tag = 8; // Struct
                    t_variant.Struct.struct_name = std.Clone(ctx, variant_struct_name);
                    t_variant.Struct.brand = empty[Index[str, ctx]];

                    enum_layout.fields.Insert(std.Clone(ctx, v.name), t_variant);
                    i = i + 1;
                }
            }

            env_register_struct(env, namespaced_name, enum_layout, ctx);
            unsafe {
                (*env).enum_registry.Insert(std.Clone(ctx, namespaced_name), variants_list);
            }
        }
    }
    if stmt.tag == 3 { // FunctionDecl
        mut name := stmt.FunctionDecl.name;
        mut namespaced_name := env_resolve_namespaced_ident(env, name, ctx);

        mut sig: FunctionSignature[ctx];
        sig.param_names = std.VectorNew(ctx);
        sig.params = std.VectorNew(ctx);

        unsafe {
            mut params_vec := &ctx[stmt.FunctionDecl.params] as *std.Vector[ast.Parameter[ctx], ctx];
            mut i := 0;
            while i < len(*params_vec) {
                mut p := (*params_vec)[i];
                sig.param_names.Push(std.Clone(ctx, p.name));
                sig.params.Push(env_resolve_type(env, p.param_type, ctx));
                i = i + 1;
            }
            sig.return_type = env_resolve_type(env, ctx[stmt.FunctionDecl.return_type], ctx);
            sig.return_origins = set_init(ctx);
        }

        env_register_function(env, namespaced_name, sig, ctx);
    }
}

func report_error(kind_tag: int, message: str, span: token.Span, env: *TypeEnvironment[ctx], ctx: &Arena) { 
    mut err_msg := std.Format("TypeError at line %d:%d: %s", span.start.line, span.start.column, message);
    typechecker_log_trace("❌", err_msg, ctx);

    unsafe {
        mut err: errors.CompilerError[ctx];
        err.kind.tag = kind_tag; // 2 for TypeError
        err.message = std.Clone(ctx, message);
        err.span = span;
        (*env).errors.Push(err);
    }
}

func typechecker_log_trace(emoji: str, message: str, ctx: &Arena) {
    mut formatted := std.Format("%s %s", emoji, message);
    os.LogStr(formatted);
}

func get_expression_span(expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) token.Span {
    mut s: token.Span;
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return s;
        }
        mut expr := ctx[expr_idx];
        mut tag := expr.tag;
        if tag == 0 { s = expr.Identifier.span; }
        if tag == 1 { s = expr.Integer.span; }
        if tag == 2 { s = expr.String.span; }
        if tag == 3 { s = expr.Bool.span; }
        if tag == 4 { s = expr.Move.span; }
        if tag == 5 { s = expr.Take.span; }
        if tag == 6 { s = expr.AddressOf.span; }
        if tag == 7 { s = expr.Dereference.span; }
        if tag == 8 { s = expr.IndexAccess.span; }
        if tag == 9 { s = expr.AsCast.span; }
        if tag == 10 { s = expr.Binary.span; }
        if tag == 11 { s = expr.Selector.span; }
        if tag == 12 { s = expr.Call.span; }
        if tag == 13 { s = expr.Empty.span; }
    }
    return s;
}

func get_root_variable(expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut expr_ptr := &ctx[expr_idx] as *ast.Expression[ctx];
        if (*expr_ptr).tag == 0 { // Identifier
            return (*expr_ptr).Identifier.name;
        }
        if (*expr_ptr).tag == 4 { // Move
            return get_root_variable((*expr_ptr).Move.expr, ctx);
        }
        if (*expr_ptr).tag == 5 { // Take
            return get_root_variable((*expr_ptr).Take.expr, ctx);
        }
        if (*expr_ptr).tag == 6 { // AddressOf
            return get_root_variable((*expr_ptr).AddressOf.expr, ctx);
        }
        if (*expr_ptr).tag == 7 { // Dereference
            return get_root_variable((*expr_ptr).Dereference.expr, ctx);
        }
        if (*expr_ptr).tag == 8 { // IndexAccess
            return get_root_variable((*expr_ptr).IndexAccess.allocator, ctx);
        }
        if (*expr_ptr).tag == 9 { // AsCast
            return get_root_variable((*expr_ptr).AsCast.left, ctx);
        }
        if (*expr_ptr).tag == 11 { // Selector
            return get_root_variable((*expr_ptr).Selector.left, ctx);
        }
        return "";
    }
}

func is_pointer_write(expr_idx: Index[ast.Expression[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) int {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return 0;
        }
        mut expr := ctx[expr_idx];
        if expr.tag == 7 { // Dereference
            return 1;
        }
        if expr.tag == 8 { // IndexAccess
            return 1;
        }
        if expr.tag == 11 { // Selector
            mut left_t := check_expression(expr.Selector.left, env, scope, ctx);
            if left_t.tag == 9 { // RawPointer
                return 1;
            }
            return is_pointer_write(expr.Selector.left, env, scope, ctx);
        }
        if expr.tag == 9 { // AsCast
            return is_pointer_write(expr.AsCast.left, env, scope, ctx);
        }
        if expr.tag == 4 { // Move
            return is_pointer_write(expr.Move.expr, env, scope, ctx);
        }
        if expr.tag == 5 { // Take
            return is_pointer_write(expr.Take.expr, env, scope, ctx);
        }
        return 0;
    }
}

func get_call_func_name(func_expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) str {
    unsafe {
        if func_expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut expr_ptr := &ctx[func_expr_idx] as *ast.Expression[ctx];
        if (*expr_ptr).tag == 0 { // Identifier
            return (*expr_ptr).Identifier.name;
        }
        if (*expr_ptr).tag == 11 { // Selector
            mut left_expr_idx := (*expr_ptr).Selector.left;
            if left_expr_idx != empty[Index[ast.Expression[ctx], ctx]] {
                mut left_ptr := &ctx[left_expr_idx] as *ast.Expression[ctx];
                if (*left_ptr).tag == 0 { // Identifier
                    return std.Clone(ctx, std.Concat(std.Concat((*left_ptr).Identifier.name, "."), (*expr_ptr).Selector.right));
                }
            }
        }
        return "";
    }
}

func is_diverging_statement(stmt_idx: Index[ast.Statement[ctx], ctx], env: *TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return 0;
        }
        mut stmt := ctx[stmt_idx];
        if stmt.tag == 12 { // Return
            return 1;
        }
        if stmt.tag == 13 { // Expression
            mut expr_idx := stmt.Expression.expr;
            if expr_idx != empty[Index[ast.Expression[ctx], ctx]] {
                mut expr := ctx[expr_idx];
                if expr.tag == 12 { // Call
                    mut func_name := get_call_func_name(expr.Call.function, ctx);
                    mut resolved_func := env_resolve_namespaced_ident(env, func_name, ctx);
                    if std.str_eq(resolved_func, "os_Exit") || std.str_eq(resolved_func, "os.Exit") {
                        return 1;
                    }
                }
            }
        }
        if stmt.tag == 10 { // UnsafeBlock
            return is_diverging_block(stmt.UnsafeBlock.body, env, ctx);
        }
        if stmt.tag == 7 { // If
            mut cons_div := is_diverging_block(stmt.If.consequence, env, ctx);
            mut alt_div := 0;
            if stmt.If.alternative != empty[Index[ast.BlockStatement[ctx], ctx]] {
                alt_div = is_diverging_block(stmt.If.alternative, env, ctx);
            }
            if cons_div == 1 && alt_div == 1 {
                return 1;
            }
        }
        return 0;
    }
}

func is_diverging_block(block_idx: Index[ast.BlockStatement[ctx], ctx], env: *TypeEnvironment[ctx], ctx: &Arena) int {
    unsafe {
        if block_idx == empty[Index[ast.BlockStatement[ctx], ctx]] {
            return 0;
        }
        mut block := ctx[block_idx];
        mut statements_vec := &ctx[block.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut i := 0;
        while i < len(*statements_vec) {
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[i];
            if is_diverging_statement(stmt_idx, env, ctx) == 1 {
                return 1;
            }
            i = i + 1;
        }
        return 0;
    }
}

func expression_to_string(expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut expr_ptr := &ctx[expr_idx] as *ast.Expression[ctx];
        if (*expr_ptr).tag == 0 { // Identifier
            return (*expr_ptr).Identifier.name;
        }
        if (*expr_ptr).tag == 11 { // Selector
            mut left_str := expression_to_string((*expr_ptr).Selector.left, ctx);
            return std.Clone(ctx, std.Concat(std.Concat(left_str, "."), (*expr_ptr).Selector.right));
        }
        if (*expr_ptr).tag == 8 { // IndexAccess
            mut alloc_str := expression_to_string((*expr_ptr).IndexAccess.allocator, ctx);
            mut idx_str := expression_to_string((*expr_ptr).IndexAccess.index, ctx);
            return std.Clone(ctx, std.Concat(std.Concat(std.Concat(alloc_str, "["), idx_str), "]"));
        }
        return "";
    }
}

func extract_ok_checked_variable(expr_idx: Index[ast.Expression[ctx], ctx], ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut expr_ptr := &ctx[expr_idx] as *ast.Expression[ctx];
        if (*expr_ptr).tag == 11 { // Selector
            if std.str_eq((*expr_ptr).Selector.right, "Ok") {
                return expression_to_string((*expr_ptr).Selector.left, ctx);
            }
        }
        if (*expr_ptr).tag == 10 { // Binary
            if std.str_eq((*expr_ptr).Binary.op, "==") {
                // Case: path.Ok == 1
                mut left_idx := (*expr_ptr).Binary.left;
                mut right_idx := (*expr_ptr).Binary.right;
                if left_idx != empty[Index[ast.Expression[ctx], ctx]] && right_idx != empty[Index[ast.Expression[ctx], ctx]] {
                    mut left_ptr := &ctx[left_idx] as *ast.Expression[ctx];
                    mut right_ptr := &ctx[right_idx] as *ast.Expression[ctx];
                    if (*left_ptr).tag == 11 { // Selector
                        if std.str_eq((*left_ptr).Selector.right, "Ok") {
                            if (*right_ptr).tag == 1 { // Integer
                                if (*right_ptr).Integer.val == 1 {
                                    return expression_to_string((*left_ptr).Selector.left, ctx);
                                }
                            }
                        }
                    }
                    if (*right_ptr).tag == 11 { // Selector
                        if std.str_eq((*right_ptr).Selector.right, "Ok") {
                            if (*left_ptr).tag == 1 { // Integer
                                if (*left_ptr).Integer.val == 1 {
                                    return expression_to_string((*right_ptr).Selector.left, ctx);
                                }
                            }
                        }
                    }
                }
            }
        }
        return "";
    }
}

func get_type_brand(t: ast.Type[ctx], ctx: &Arena) str {
    unsafe {
        if t.tag == 7 { // Index
            if t.Index.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                return *brand_str_ptr;
            }
        }
        if t.tag == 8 { // Struct
            if t.Struct.brand != empty[Index[str, ctx]] {
                mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                return *brand_str_ptr;
            }
        }
        if t.tag == 9 { // RawPointer
            return get_type_brand(ctx[t.RawPointer.inner], ctx);
        }
        if t.tag == 6 { // Slice
            return get_type_brand(ctx[t.Slice.inner], ctx);
        }
        return "";
    }
}

func types_match(expected: ast.Type[ctx], actual: ast.Type[ctx], ctx: &Arena) int {
    unsafe {
        if expected.tag != actual.tag {
            // Handle Int/Byte match
            if (expected.tag == 0 && actual.tag == 1) || (expected.tag == 1 && actual.tag == 0) {
                return 1;
            }
            return 0;
        }
        if expected.tag == 0 || expected.tag == 1 || expected.tag == 2 || expected.tag == 3 || expected.tag == 4 || expected.tag == 5 {
            return 1;
        }
        if expected.tag == 6 { // Slice
            return types_match(ctx[expected.Slice.inner], ctx[actual.Slice.inner], ctx);
        }
        if expected.tag == 9 { // RawPointer
            return types_match(ctx[expected.RawPointer.inner], ctx[actual.RawPointer.inner], ctx);
        }

if expected.tag == 7 { // Index
                mut name1 := expected.Index.struct_name;
                mut name2 := actual.Index.struct_name;
                name1 = strip_brand_prefix(name1, ctx);
                name2 = strip_brand_prefix(name2, ctx);
                if std.str_eq(name1, name2) || std.str_eq(name1, "Any") || std.str_eq(name2, "Any") {
                    return 1;
                }
                return 0;
            }

            if expected.tag == 8 { // Struct
                    mut name1 := expected.Struct.struct_name;
                    mut name2 := actual.Struct.struct_name;
                    if std.str_eq(name1, name2) || std.str_eq(name1, "Any") || std.str_eq(name2, "Any") {
                        return 1;
                    }

                    if len(name1) >= 4 {
                        if std.str_eq(std.str_slice(name1, 0, 4), "std_") {
                            name1 = std.str_slice(name1, 4, len(name1));
                        }
                    }
                    if len(name2) >= 4 {
                        if std.str_eq(std.str_slice(name2, 0, 4), "std_") {
                            name2 = std.str_slice(name2, 4, len(name2));
                        }
                    }

                    name1 = strip_brand_prefix(name1, ctx);
                    name2 = strip_brand_prefix(name2, ctx);

                    mut prefixes: std.Vector[str, ctx] := std.VectorNew(ctx);
        
                prefixes.Push("Vector_");
                prefixes.Push("HashMap_");
                prefixes.Push("Pool_");
                prefixes.Push("Rc_");
                prefixes.Push("Graph_");
                prefixes.Push("Mutex_");
                prefixes.Push("Channel_");
                prefixes.Push("GenerationalArena_");
                prefixes.Push("os_Dir_");
                prefixes.Push("os_DirEntry_");

                mut p := 0;
                while p < len(prefixes) {
                    mut prefix := prefixes[p];
                    mut is_prefix1 := 0;
                    if len(name1) >= len(prefix) {
                        if std.str_eq(std.str_slice(name1, 0, len(prefix)), prefix) {
                            is_prefix1 = 1;
                        }
                    }
                    mut is_prefix2 := 0;
                    if len(name2) >= len(prefix) {
                        if std.str_eq(std.str_slice(name2, 0, len(prefix)), prefix) {
                            is_prefix2 = 1;
                        }
                    }

                    if is_prefix1 == 1 && is_prefix2 == 1 {
                        mut brand1 := get_type_brand(expected, ctx);
                        mut brand2 := get_type_brand(actual, ctx);
                        if std.str_eq(brand1, brand2) {
                            return 1;
                        }
                    }
                    p = p + 1;
                }
                return 0;
            }
        
        if expected.tag == 10 { // Generic
            if std.str_eq(expected.Generic.name, actual.Generic.name) {
                return 1;
            }
            return 0;
        }
        return 0;
    }
}

func check_statement(stmt_idx: Index[ast.Statement[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) errors.Result[int, ctx] {
    unsafe {
        mut res: errors.Result[int, ctx];
        res.tag = 0; // Ok
        res.Ok.val = 0;

        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return res;
        }

        mut stmt := ctx[stmt_idx];
        mut err_count := len((*env).errors);
        mut start_msg := std.Format("check_statement: start for stmt tag %d", stmt.tag);
        typechecker_log_trace("📥", start_msg, ctx);

        res = check_statement_impl(stmt_idx, env, scope, ctx);

        if len((*env).errors) == err_count {
            mut success_msg := std.Format("check_statement: successfully verified stmt tag %d", stmt.tag);
            typechecker_log_trace("✅", success_msg, ctx);
        }
        return res;
    }
}

func check_statement_impl(stmt_idx: Index[ast.Statement[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) errors.Result[int, ctx] {
    unsafe {
        mut res: errors.Result[int, ctx];
        res.tag = 0; // Ok
        res.Ok.val = 0;

        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return res;
        }

        mut stmt := ctx[stmt_idx];

        if stmt.tag == 0 || stmt.tag == 1 || stmt.tag == 2 {
            return res;
        }

        if stmt.tag == 3 { // FunctionDecl
            mut params_vec := &ctx[stmt.FunctionDecl.params] as *std.Vector[ast.Parameter[ctx], ctx];
            mut return_type_idx := stmt.FunctionDecl.return_type;
            mut body_idx := stmt.FunctionDecl.body;

            // Save parent states
            mut parent_moved := (*env).moved_vars;
            mut parent_checked := (*env).checked_results;
            mut parent_open_dirs := (*env).open_directories;

            // Clear states
            (*env).moved_vars = std.HashMapNew(ctx);
            (*env).checked_results = std.HashMapNew(ctx);
            (*env).open_directories = std.HashMapNew(ctx);

            mut child_scope := scope_new(scope, ctx);

            // Register parameters
            mut inout_params: std.Vector[str, ctx] := std.VectorNew(ctx);
            mut i := 0;
            while i < len(*params_vec) {
                mut param := (*params_vec)[i];
                mut resolved_param_type := env_resolve_type(env, param.param_type, ctx);
                
                if resolved_param_type.tag == 9 { // RawPointer
                    inout_params.Push(std.Clone(ctx, param.name));
                }
                
                scope_insert(child_scope, param.name, resolved_param_type, ctx);
                
                mut param_origins := set_init(ctx);
                set_add(param_origins, param.name, ctx);
                (*env).variable_origins.Insert(std.Clone(ctx, param.name), param_origins);
                
                i = i + 1;
            }

            // Save old function contexts
            mut old_expected := (*env).expected_return_type;
            mut old_return_origins := (*env).current_function_return_origins;
            mut old_inout_params := (*env).current_function_inout_params;
            mut old_local_vars := (*env).current_function_local_vars;

            mut resolved_ret_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[resolved_ret_idx] = env_resolve_type(env, ctx[return_type_idx], ctx);
            (*env).expected_return_type = resolved_ret_idx;
            (*env).current_function_return_origins = set_init(ctx);
            
            mut inout_params_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
            mut dest_ptr := &ctx[inout_params_idx] as *std.Vector[str, ctx];
            *dest_ptr = inout_params;
            (*env).current_function_inout_params = inout_params_idx;
            (*env).current_function_local_vars = set_init(ctx);

            // Evaluate body statements
            if body_idx != empty[Index[ast.BlockStatement[ctx], ctx]] {
                mut body := ctx[body_idx];
                mut statements_vec := &ctx[body.statements] as *std.Vector[ast.Statement[ctx], ctx];
                mut j := 0;
                while j < len(*statements_vec) {
                    mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[s_idx] = (*statements_vec)[j];
                    check_statement(s_idx, env, child_scope, ctx);
                    j = j + 1;
                }
            }

            // Check inout params are not moved
            mut current_inouts := &ctx[(*env).current_function_inout_params] as *std.Vector[str, ctx];
            mut k := 0;
            while k < len(*current_inouts) {
                mut inout_p := (*current_inouts)[k];
                if (*env).moved_vars.Get(inout_p).Ok {
                    mut msg := std.Concat("Semantic Error: Inout reference parameter '", inout_p);
                    msg = std.Concat(msg, "' was moved but never re-initialized before function exit");
                    report_error(2, msg, stmt.FunctionDecl.span, env, ctx);
                }
                k = k + 1;
            }

            // Directory leak checking
            mut local_vars := (*env).current_function_local_vars;
            mut local_var_keys := ctx[local_vars].map.Keys(ctx);
            mut m := 0;
            while m < len(local_var_keys) {
                mut local_var := local_var_keys[m];
                if (*env).open_directories.Get(local_var).Ok {
                    mut msg := std.Concat("Semantic Error: Resource leak. Directory resource variable '", local_var);
                    msg = std.Concat(msg, "' must be cleanly closed with os.CloseDir before leaving local scope");
                    report_error(2, msg, stmt.FunctionDecl.span, env, ctx);
                }
                m = m + 1;
            }

            // Restore parent states
            (*env).moved_vars = parent_moved;
            (*env).checked_results = parent_checked;
            (*env).open_directories = parent_open_dirs;
            (*env).expected_return_type = old_expected;
            (*env).current_function_return_origins = old_return_origins;
            (*env).current_function_inout_params = old_inout_params;
            (*env).current_function_local_vars = old_local_vars;

            return res;
        }

        if stmt.tag == 4 { // VarDecl
            mut name := stmt.VarDecl.name;
            mut val_idx := stmt.VarDecl.value;
            mut var_type_idx := stmt.VarDecl.var_type;

            mut val_type: ast.Type[ctx];
            val_type.tag = 3; // Void

if val_idx != empty[Index[ast.Expression[ctx], ctx]] {
                val_type = check_expression(val_idx, env, scope, ctx);
                val_type = env_resolve_type(env, val_type, ctx);

                mut origs := set_init(ctx);
                if env_type_is_ephemeral_view(val_type, ctx) == 1 {
                    origs = get_expression_origins(val_idx, env, ctx);
                    if ctx[origs].map.len == 0 {
                        set_add(origs, name, ctx);
                    }
                }
                (*env).variable_origins.Insert(std.Clone(ctx, name), origs);
            } else {
                if var_type_idx != empty[Index[ast.Type[ctx], ctx]] {
                    mut origs := set_init(ctx);
                    mut resolved := env_resolve_type(env, ctx[var_type_idx], ctx);
                    val_type = resolved;
                    if env_type_is_ephemeral_view(val_type, ctx) == 1 {
                        set_add(origs, name, ctx);
                    }
                    (*env).variable_origins.Insert(std.Clone(ctx, name), origs);
                } else {
                    mut msg := std.Concat("Semantic Error: Uninitialized variable '", name);
                    msg = std.Concat(msg, "' must have an explicit type annotation");
                    report_error(2, msg, stmt.VarDecl.span, env, ctx);
                }
            }

            if var_type_idx != empty[Index[ast.Type[ctx], ctx]] {
                mut resolved_explicit := env_resolve_type(env, ctx[var_type_idx], ctx);
                if types_match(resolved_explicit, val_type, ctx) == 0 {
                    mut msg := "Semantic Error: Explicit Type Annotation Mismatch. Declared ";
                    msg = std.Concat(msg, ast.serialize_type(resolved_explicit, ctx));
                    msg = std.Concat(msg, " but got value ");
                    msg = std.Concat(msg, ast.serialize_type(val_type, ctx));
                    
                    mut val_span: token.Span;
                    if val_idx != empty[Index[ast.Expression[ctx], ctx]] {
                        val_span = get_expression_span(val_idx, ctx);
                    } else { 
                        val_span = stmt.VarDecl.span;
                    }
                    report_error(2, msg, val_span, env, ctx);
                }
                scope_insert(scope, name, resolved_explicit, ctx);
                (*env).variable_types.Insert(std.Clone(ctx, name), resolved_explicit);
            } else {
                scope_insert(scope, name, val_type, ctx);
                (*env).variable_types.Insert(std.Clone(ctx, name), val_type);
            }

            if val_type.tag == 8 { // Struct
                mut decl_struct_name := val_type.Struct.struct_name;
                if len(decl_struct_name) >= 7 && std.str_eq(std.str_slice(decl_struct_name, 0, 7), "os_Dir_") {
                    (*env).open_directories.Insert(std.Clone(ctx, name), 1);
                }
            }

            if (*env).current_function_local_vars != empty[Index[OriginSet[ctx], ctx]] {
                mut local_vars := (*env).current_function_local_vars;
                set_add(local_vars, name, ctx);
            }

            return res;
        }

        if stmt.tag == 5 { // Assignment
            mut left_idx := stmt.Assignment.left;
            mut val_idx := stmt.Assignment.value;

            mut left_type: ast.Type[ctx];
            left_type.tag = 3; // Void

            mut left := ctx[left_idx];
            if left.tag == 0 { // Identifier
                mut name := left.Identifier.name;
                mut resolved_name := name;
                mut is_local := scope_contains(scope, name, ctx);
                if is_local == 0 {
                    resolved_name = env_resolve_namespaced_ident(env, name, ctx);
                }
                left_type = scope_lookup(scope, resolved_name, ctx);
                if left_type.tag == 3 {
                    mut msg := std.Concat("Semantic Error: Undefined variable '", name);
                    msg = std.Concat(msg, "' in assignment LHS");
                    report_error(2, msg, left.Identifier.span, env, ctx);
                }
            } else {
                left_type = check_expression(left_idx, env, scope, ctx);
            }

            mut val_type := check_expression(val_idx, env, scope, ctx);
            val_type = env_resolve_type(env, val_type, ctx);

            if types_match(left_type, val_type, ctx) == 0 {
                mut msg := "Semantic Error: Mismatched types in assignment. Cannot assign ";
                msg = std.Concat(msg, ast.serialize_type(val_type, ctx));
                msg = std.Concat(msg, " to ");
                msg = std.Concat(msg, ast.serialize_type(left_type, ctx));
                report_error(2, msg, get_expression_span(val_idx, ctx), env, ctx);
            }

            // Scratchpad storage restriction check (Step 3 verification)
            if left.tag == 11 { // Selector
                mut parent_type := check_expression(left.Selector.left, env, scope, ctx);
                mut parent_brand := get_type_brand(parent_type, ctx);
                if std.str_eq(parent_brand, "") == 0 {
                    mut rhs_origins := get_expression_origins(val_idx, env, ctx);
                    if set_contains(rhs_origins, "scratch", ctx) == 1 {
                        mut msg := "Semantic Error: Cannot assign scratchpad-allocated view to field of branded struct ";
                        msg = std.Concat(msg, ast.serialize_type(parent_type, ctx));
                        report_error(2, msg, get_expression_span(val_idx, ctx), env, ctx);
                    }
                }
            }

            mut is_ptr_write := is_pointer_write(left_idx, env, scope, ctx);

            if is_ptr_write == 0 {
                mut root_name := get_root_variable(left_idx, ctx);
                if std.str_eq(root_name, "") == 0 {
                    // Invalidate any active views that borrow from the root variable being modified
                    mut var_origins_keys := (*env).variable_origins.Keys(ctx);
                    mut m := 0;
                    while m < len(var_origins_keys) {
                        mut var_name := var_origins_keys[m];
                        if std.str_eq(var_name, root_name) == 0 {
                            mut lookup_origins := (*env).variable_origins.Get(var_name);
                            if lookup_origins.Ok {
                                mut origins := lookup_origins.Val;
                                if set_contains(origins, root_name, ctx) == 1 {
                                    (*env).moved_vars.Insert(std.Clone(ctx, var_name), 1);
                                }
                            }
                        }
                        m = m + 1;
                    }

                    // Track assignments to variables to update their active memory origins
                    mut origs := set_init(ctx);
                    if env_type_is_ephemeral_view(left_type, ctx) == 1 {
                        origs = get_expression_origins(val_idx, env, ctx);
                    }
                    if left.tag == 0 { // Identifier
                        if ctx[origs].map.len == 0 {
                            set_add(origs, root_name, ctx);
                        }
                        (*env).variable_origins.Insert(std.Clone(ctx, root_name), origs);
                    } else {
                        if ctx[origs].map.len > 0 {
                            mut existing_lookup := (*env).variable_origins.Get(root_name);
                            if existing_lookup.Ok {
                                set_union(existing_lookup.Val, origs, ctx);
                            } else {
                                (*env).variable_origins.Insert(std.Clone(ctx, root_name), origs);
                            }
                        }
                    }
                    (*env).moved_vars.Remove(root_name); // Re-initialized!

                    if val_type.tag == 8 { // Struct
                        mut assign_struct_name := val_type.Struct.struct_name;
                        if len(assign_struct_name) >= 7 && std.str_eq(std.str_slice(assign_struct_name, 0, 7), "os_Dir_") {
                            (*env).open_directories.Insert(std.Clone(ctx, root_name), 1);
                        }
                    }
                }
            }

            return res;
        }

        if stmt.tag == 6 { // While
            mut cond_idx := stmt.While.condition;
            mut body_idx := stmt.While.body;

            mut cond_type := check_expression(cond_idx, env, scope, ctx);
            if cond_type.tag != 0 && cond_type.tag != 2 { // Int or Bool
                mut msg := "Semantic Error: Loop condition must evaluate to an Int or Bool (binary comparison or boolean)";
                report_error(2, msg, get_expression_span(cond_idx, ctx), env, ctx);
            }

            mut parent_moved := (*env).moved_vars;
            mut parent_origins := (*env).variable_origins;

            if body_idx != empty[Index[ast.BlockStatement[ctx], ctx]] {
                mut body := ctx[body_idx];
                mut statements_vec := &ctx[body.statements] as *std.Vector[ast.Statement[ctx], ctx];
                mut j := 0;
                while j < len(*statements_vec) {
                    mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[s_idx] = (*statements_vec)[j];
                    check_statement(s_idx, env, scope, ctx);
                    j = j + 1;
                }
            }

            (*env).moved_vars = parent_moved;
            (*env).variable_origins = parent_origins;

            return res;
        }

        if stmt.tag == 7 { // If
            mut cond_idx := stmt.If.condition;
            mut cons_idx := stmt.If.consequence;
            mut alt_idx := stmt.If.alternative;

            mut cond_type := check_expression(cond_idx, env, scope, ctx);
            if cond_type.tag != 0 && cond_type.tag != 2 { // Int or Bool
                mut msg := "Semantic Error: If condition must evaluate to an Int or Bool (binary comparison or boolean)";
                report_error(2, msg, get_expression_span(cond_idx, ctx), env, ctx);
            }

            mut pre_origins := (*env).variable_origins;
            mut pre_moved := (*env).moved_vars;
            mut pre_checked := (*env).checked_results;

            mut checked_var := extract_ok_checked_variable(cond_idx, ctx);
            if std.str_eq(checked_var, "") == 0 {
                (*env).checked_results.Insert(std.Clone(ctx, checked_var), 1);
            }

            // Evaluate consequence
            if cons_idx != empty[Index[ast.BlockStatement[ctx], ctx]] {
                mut cons := ctx[cons_idx];
                mut statements_vec := &ctx[cons.statements] as *std.Vector[ast.Statement[ctx], ctx];
                mut j := 0;
                while j < len(*statements_vec) {
                    mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[s_idx] = (*statements_vec)[j];
                    check_statement(s_idx, env, scope, ctx);
                    j = j + 1;
                }
            }

            mut consequence_origins := (*env).variable_origins;
            mut consequence_moved := (*env).moved_vars;

            if alt_idx != empty[Index[ast.BlockStatement[ctx], ctx]] {
                // Reset to pre-if state for alternative branch evaluation
                (*env).variable_origins = pre_origins;
                (*env).moved_vars = pre_moved;
                (*env).checked_results = pre_checked;

                mut alt := ctx[alt_idx];
                mut statements_vec := &ctx[alt.statements] as *std.Vector[ast.Statement[ctx], ctx];
                mut j := 0;
                while j < len(*statements_vec) {
                    mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[s_idx] = (*statements_vec)[j];
                    check_statement(s_idx, env, scope, ctx);
                    j = j + 1;
                }

                mut alternative_origins := (*env).variable_origins;
                mut alternative_moved := (*env).moved_vars;

                // Join consequence and alternative
                mut merged_origins := pre_origins;
                
                // Add consequence keys
                mut conseq_keys := consequence_origins.Keys(ctx);
                mut m := 0;
                while m < len(conseq_keys) {
                    mut key := conseq_keys[m];
                    mut lookup_conseq := consequence_origins.Get(key);
                    if lookup_conseq.Ok {
                        mut orig_conseq := lookup_conseq.Val;
                        mut orig_alt_lookup := alternative_origins.Get(key);
                        
                        mut union_set := set_init(ctx);
                        set_union(union_set, orig_conseq, ctx);
                        if orig_alt_lookup.Ok {
                            set_union(union_set, orig_alt_lookup.Val, ctx);
                        } else {
                            mut pre_lookup := pre_origins.Get(key);
                            if pre_lookup.Ok {
                                set_union(union_set, pre_lookup.Val, ctx);
                            }
                        }
                        merged_origins.Insert(std.Clone(ctx, key), union_set);
                    }
                    m = m + 1;
                }

                // Add alternative keys that are not in consequence
                mut alt_keys := alternative_origins.Keys(ctx);
                mut n := 0;
                while n < len(alt_keys) {
                    mut key := alt_keys[n];
                    if consequence_origins.Get(key).Ok == 0 {
                        mut lookup_alt := alternative_origins.Get(key);
                        if lookup_alt.Ok {
                            mut orig_alt := lookup_alt.Val;
                            mut union_set := set_init(ctx);
                            set_union(union_set, orig_alt, ctx);
                            mut pre_lookup := pre_origins.Get(key);
                            if pre_lookup.Ok {
                                set_union(union_set, pre_lookup.Val, ctx);
                            }
                            merged_origins.Insert(std.Clone(ctx, key), union_set);
                        }
                    }
                    n = n + 1;
                }

                mut merged_moved := pre_moved;
                // Merge consequence_moved
                mut conseq_moved_keys := consequence_moved.Keys(ctx);
                mut p := 0;
                while p < len(conseq_moved_keys) {
                    merged_moved.Insert(std.Clone(ctx, conseq_moved_keys[p]), 1);
                    p = p + 1;
                }
                // Merge alternative_moved
                mut alt_moved_keys := alternative_moved.Keys(ctx);
                mut q := 0;
                while q < len(alt_moved_keys) {
                    merged_moved.Insert(std.Clone(ctx, alt_moved_keys[q]), 1);
                    q = q + 1;
                }

                (*env).variable_origins = merged_origins;
                (*env).moved_vars = merged_moved;
            } else {
                // Merge consequence with pre-if
                mut merged_origins := pre_origins;
                mut conseq_keys := consequence_origins.Keys(ctx);
                mut m := 0;
                while m < len(conseq_keys) {
                    mut key := conseq_keys[m];
                    mut lookup_conseq := consequence_origins.Get(key);
                    if lookup_conseq.Ok {
                        mut c_set := lookup_conseq.Val;
                        mut pre_lookup := pre_origins.Get(key);
                        if pre_lookup.Ok {
                            mut union_set := set_init(ctx);
                            set_union(union_set, pre_lookup.Val, ctx);
                            set_union(union_set, c_set, ctx);
                            merged_origins.Insert(std.Clone(ctx, key), union_set);
                        } else {
                            merged_origins.Insert(std.Clone(ctx, key), c_set);
                        }
                    }
                    m = m + 1;
                }

                mut merged_moved := pre_moved;
                mut conseq_moved_keys := consequence_moved.Keys(ctx);
                mut p := 0;
                while p < len(conseq_moved_keys) {
                    merged_moved.Insert(std.Clone(ctx, conseq_moved_keys[p]), 1);
                    p = p + 1;
                }

                (*env).variable_origins = merged_origins;
                (*env).moved_vars = merged_moved;
            }

            // Restore checked results
            (*env).checked_results = pre_checked;

            return res;
        }

        if stmt.tag == 8 { // Match
            mut expr_idx := stmt.Match.expression;
            mut cases_vec := &ctx[stmt.Match.cases] as *std.Vector[ast.MatchCase[ctx], ctx];

            mut expr_type := check_expression(expr_idx, env, scope, ctx);
            if expr_type.tag == 8 { // Struct
                mut enum_name := expr_type.Struct.struct_name;
                mut matched_variants: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);

                mut i := 0;
                while i < len(*cases_vec) {
                    mut m_case := (*cases_vec)[i];
                    mut variant_name := m_case.variant_name;

                    matched_variants.Insert(std.Clone(ctx, variant_name), 1);

                    // Typecheck the case body in its own scope
                    mut parent_scope := scope;
                    mut parent_origins := (*env).variable_origins;

                    mut child_scope := scope_new(scope, ctx);

                    if len(ctx[m_case.fields]) > 0 {
                        mut variant_struct_name := std.Concat(std.Concat(enum_name, "_"), variant_name);
                        mut lookup_variant := (*env).struct_registry.Get(variant_struct_name);
                        if lookup_variant.Ok {
                            mut fields_vec := &ctx[m_case.fields] as *std.Vector[str, ctx];
                            mut f := 0;
                            while f < len(*fields_vec) {
                                mut field_name := (*fields_vec)[f];
                                mut field_type_lookup := lookup_variant.Val.fields.Get(field_name);
                                if field_type_lookup.Ok {
                                    scope_insert(child_scope, field_name, field_type_lookup.Val, ctx);

                                    // Flow origins
                                    mut parent_origins_set := get_expression_origins(expr_idx, env, ctx);
                                    mut final_origins := set_init(ctx);
                                    if env_type_is_ephemeral_view(field_type_lookup.Val, ctx) == 1 {
                                        final_origins = parent_origins_set;
                                    }
                                    if set_contains(final_origins, field_name, ctx) == 0 && ctx[final_origins].map.len == 0 {
                                        set_add(final_origins, field_name, ctx);
                                    }
                                    (*env).variable_origins.Insert(std.Clone(ctx, field_name), final_origins);

                                    if (*env).current_function_local_vars != empty[Index[OriginSet[ctx], ctx]] {
                                        mut local_vars := (*env).current_function_local_vars;
                                        set_add(local_vars, field_name, ctx);
                                    }
                                }
                                f = f + 1;
                            }
                        }
                    }

                    if m_case.body != empty[Index[ast.BlockStatement[ctx], ctx]] {
                        mut body := ctx[m_case.body];
                        mut statements_vec := &ctx[body.statements] as *std.Vector[ast.Statement[ctx], ctx];
                        mut j := 0;
                        while j < len(*statements_vec) {
                            mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                            ctx[s_idx] = (*statements_vec)[j];
                            check_statement(s_idx, env, child_scope, ctx);
                            j = j + 1;
                        }
                    }

                    // Restore parents
                    (*env).variable_origins = parent_origins;

                    i = i + 1;
                }
            }

            return res;
        }

        if stmt.tag == 10 { // UnsafeBlock
            mut body_idx := stmt.UnsafeBlock.body;
            mut was_unsafe := (*env).in_unsafe_block;
            (*env).in_unsafe_block = 1;

            if body_idx != empty[Index[ast.BlockStatement[ctx], ctx]] {
                mut body := ctx[body_idx];
                mut statements_vec := &ctx[body.statements] as *std.Vector[ast.Statement[ctx], ctx];
                mut j := 0;
                while j < len(*statements_vec) {
                    mut s_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                    ctx[s_idx] = (*statements_vec)[j];
                    check_statement(s_idx, env, scope, ctx);
                    j = j + 1;
                }
            }

            (*env).in_unsafe_block = was_unsafe;

            return res;
        }

        if stmt.tag == 11 { // Defer
            mut expr_idx := stmt.Defer.expr;
            check_expression(expr_idx, env, scope, ctx);

            return res;
        }

        if stmt.tag == 12 { // Return
            mut expr_idx := stmt.Return.expr;

            // Check inout parameters are not moved before returning
            if (*env).current_function_inout_params != empty[Index[std.Vector[str, ctx], ctx]] {
                mut inout_params := &ctx[(*env).current_function_inout_params] as *std.Vector[str, ctx];
                mut k := 0;
                while k < len(*inout_params) {
                    mut inout_p := (*inout_params)[k];
                    if (*env).moved_vars.Get(inout_p).Ok {
                        mut msg := std.Concat("Semantic Error: Inout reference parameter '", inout_p);
                        msg = std.Concat(msg, "' was moved but never re-initialized before return");
                        report_error(2, msg, stmt.Return.span, env, ctx);
                    }
                    k = k + 1;
                }
            }

            mut actual_return: ast.Type[ctx];
            actual_return.tag = 3; // Void

            if expr_idx != empty[Index[ast.Expression[ctx], ctx]] {
                actual_return = check_expression(expr_idx, env, scope, ctx);
                actual_return = env_resolve_type(env, actual_return, ctx);

                mut expr_origins := get_expression_origins(expr_idx, env, ctx);

                if set_contains(expr_origins, "scratch", ctx) == 1 {
                    mut msg := "Semantic Error: Escape analysis violation. Returning scratchpad-allocated view of type ";
                    msg = std.Concat(msg, ast.serialize_type(actual_return, ctx));
                    report_error(2, msg, get_expression_span(expr_idx, ctx), env, ctx);
                }

                if env_type_is_ephemeral_view(actual_return, ctx) == 1 {
                    if (*env).current_function_local_vars != empty[Index[OriginSet[ctx], ctx]] {
                        mut local_vars := (*env).current_function_local_vars;
                        mut local_keys := ctx[local_vars].map.Keys(ctx);
                        mut m := 0;
                        while m < len(local_keys) {
                            mut origin := local_keys[m];
                            if set_contains(expr_origins, origin, ctx) == 1 {
                                mut msg := "Semantic Error: Escape analysis violation. Returning ephemeral view of type ";
                                msg = std.Concat(msg, ast.serialize_type(actual_return, ctx));
                                msg = std.Concat(msg, " whose origin traces back to local stack variable '");
                                msg = std.Concat(msg, origin);
                                msg = std.Concat(msg, "'");
                                report_error(2, msg, get_expression_span(expr_idx, ctx), env, ctx);
                            }
                            m = m + 1;
                        } 
                    }
                }

                if (*env).current_function_return_origins != empty[Index[OriginSet[ctx], ctx]] {
                    mut return_origins := (*env).current_function_return_origins;
                    set_union(return_origins, expr_origins, ctx);
                }
            }

            if (*env).expected_return_type != empty[Index[ast.Type[ctx], ctx]] {
                mut expected_t := ctx[(*env).expected_return_type];
                if types_match(expected_t, actual_return, ctx) == 0 {
                    mut msg := "Semantic Error: Return type mismatch. Expected ";
                    msg = std.Concat(msg, ast.serialize_type(expected_t, ctx));
                    msg = std.Concat(msg, " but got ");
                    msg = std.Concat(msg, ast.serialize_type(actual_return, ctx));
                    
                    mut val_span: token.Span;
                    if expr_idx != empty[Index[ast.Expression[ctx], ctx]] {
                        val_span = get_expression_span(expr_idx, ctx);
                    } else {
                        val_span = stmt.Return.span;
                    }
                    report_error(2, msg, val_span, env, ctx);
                }
            } else {
                mut msg := "Semantic Error: Return statement used outside function body";
                report_error(2, msg, stmt.Return.span, env, ctx);
            }

            return res;
        }

        if stmt.tag == 13 { // Expression
            mut expr_idx := stmt.Expression.expr;
            check_expression(expr_idx, env, scope, ctx);

            return res;
        }

        return res;
    }
}

func typechecker_str_compare(s1: str, s2: str) int {
    mut len1 := len(s1);
    mut len2 := len(s2);
    mut min_len := len1;
    if len2 < min_len {
        min_len = len2;
    }

    mut i := 0;
    while i < min_len {
        mut b1 := std.str_byte_at(s1, i);
        mut b2 := std.str_byte_at(s2, i);
        if b1 < b2 {
            return 0 - 1;
        }
        if b1 > b2 {
            return 1;
        }
        i = i + 1;
    }

    if len1 < len2 {
        return 0 - 1;
    }
    if len1 > len2 {
        return 1;
    }
    return 0;
}

func typechecker_sort_vector_str(vec: *std.Vector[str, ctx], ctx: &Arena) {
    unsafe {
        mut n := len(*vec);
        mut i := 0;
        while i < n {
            mut min_idx := i;
            mut j := i + 1;
            while j < n {
                mut cmp := typechecker_str_compare((*vec)[j], (*vec)[min_idx]);
                if cmp < 0 {
                    min_idx = j;
                }
                j = j + 1;
            }
            if min_idx != i {
                mut temp := (*vec)[i];
                (*vec)[i] = (*vec)[min_idx];
                (*vec)[min_idx] = temp;
            }
            i = i + 1;
        }
    }
}

func typechecker_get_sorted_keys_int(map: *std.HashMap[str, int, ctx], ctx: &Arena) std.Vector[str, ctx] {
    unsafe {
        mut keys := (*map).Keys(ctx);
        typechecker_sort_vector_str(&keys, ctx);
        return keys;
    }
}

func typechecker_get_sorted_keys_type(map: *std.HashMap[str, ast.Type[ctx], ctx], ctx: &Arena) std.Vector[str, ctx] {
    unsafe {
        mut keys := (*map).Keys(ctx);
        typechecker_sort_vector_str(&keys, ctx);
        return keys;
    }
}

func typechecker_get_sorted_keys_layout(map: *std.HashMap[str, StructLayout[ctx], ctx], ctx: &Arena) std.Vector[str, ctx] {
    unsafe {
        mut keys := (*map).Keys(ctx);
        typechecker_sort_vector_str(&keys, ctx);
        return keys;
    }
}

func typechecker_get_sorted_keys_enum(map: *std.HashMap[str, std.Vector[str, ctx], ctx], ctx: &Arena) std.Vector[str, ctx] {
    unsafe {
        mut keys := (*map).Keys(ctx);
        typechecker_sort_vector_str(&keys, ctx);
        return keys;
    }
}

func typechecker_get_sorted_keys_func(map: *std.HashMap[str, FunctionSignature[ctx], ctx], ctx: &Arena) std.Vector[str, ctx] {
    unsafe {
        mut keys := (*map).Keys(ctx);
        typechecker_sort_vector_str(&keys, ctx);
        return keys;
    }
}

func typechecker_serialize_variables(env: *TypeEnvironment[ctx], ctx: &Arena) str {
    mut result := "Variables:\n";
    unsafe {
        mut keys := typechecker_get_sorted_keys_type(&(*env).variable_types, ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            mut lookup := (*env).variable_types.Get(key);
            if lookup.Ok {
                mut ty_str := ast.serialize_type(lookup.Val, ctx);
                result = std.Concat(result, "  ");
                result = std.Concat(result, key);
                result = std.Concat(result, " : ");
                result = std.Concat(result, ty_str);
                result = std.Concat(result, "\n");
            }
            i = i + 1;
        }
    }
    return std.Clone(ctx, result);
}

func typechecker_serialize_enums(env: *TypeEnvironment[ctx], ctx: &Arena) str {
    mut result := "Enums:\n";
    unsafe {
        mut keys := typechecker_get_sorted_keys_enum(&(*env).enum_registry, ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            mut lookup := (*env).enum_registry.Get(key);
            if lookup.Ok {
                result = std.Concat(result, "  ");
                result = std.Concat(result, key);
                result = std.Concat(result, ":\n");
                
                mut variants := lookup.Val;
                typechecker_sort_vector_str(&variants, ctx);
                mut j := 0;
                while j < len(variants) {
                    mut variant := variants[j];
                    result = std.Concat(result, "    ");
                    result = std.Concat(result, variant);
                    result = std.Concat(result, "\n");
                    j = j + 1;
                }
            }
            i = i + 1;
        }
    }
    return std.Clone(ctx, result);
}

func typechecker_serialize_structures(env: *TypeEnvironment[ctx], ctx: &Arena) str {
    mut result := "Structures:\n";
    unsafe {
        mut keys := typechecker_get_sorted_keys_layout(&(*env).struct_registry, ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            mut lookup := (*env).struct_registry.Get(key);
            if lookup.Ok {
                mut layout := lookup.Val;
                mut brand_str := "";
                if layout.brand != empty[Index[str, ctx]] {
                    mut brand_str_ptr := &ctx[layout.brand] as *str;
                    brand_str = std.Concat(" [", *brand_str_ptr);
                    brand_str = std.Concat(brand_str, "]");
                }
                result = std.Concat(result, "  ");
                result = std.Concat(result, key);
                result = std.Concat(result, brand_str);
                result = std.Concat(result, ":\n");
                
                mut f_keys := typechecker_get_sorted_keys_type(&layout.fields, ctx);
                mut j := 0;
                while j < len(f_keys) {
                    mut f_key := f_keys[j];
                    mut f_lookup := layout.fields.Get(f_key);
                    if f_lookup.Ok {
                        mut ty_str := ast.serialize_type(f_lookup.Val, ctx);
                        result = std.Concat(result, "    ");
                        result = std.Concat(result, f_key);
                        result = std.Concat(result, " : ");
                        result = std.Concat(result, ty_str);
                        result = std.Concat(result, "\n");
                    }
                    j = j + 1;
                }
            }
            i = i + 1;
        }
    }
    return std.Clone(ctx, result);
}

func typechecker_serialize_functions(env: *TypeEnvironment[ctx], ctx: &Arena) str {
    mut result := "Functions:\n";
    unsafe {
        mut keys := typechecker_get_sorted_keys_func(&(*env).function_registry, ctx);
        mut i := 0;
        while i < len(keys) {
            mut key := keys[i];
            mut lookup := (*env).function_registry.Get(key);
            if lookup.Ok {
                mut sig := lookup.Val;
                result = std.Concat(result, "  ");
                result = std.Concat(result, key);
                result = std.Concat(result, "(");
                
                mut params_str := "";
                mut j := 0;
                while j < len(sig.param_names) {
                    if j > 0 {
                        params_str = std.Concat(params_str, ", ");
                    }
                    mut p_name := sig.param_names[j];
                    mut p_type := sig.params[j];
                    mut p_type_str := ast.serialize_type(p_type, ctx);
                    params_str = std.Concat(params_str, p_name);
                    params_str = std.Concat(params_str, ": ");
                    params_str = std.Concat(params_str, p_type_str);
                    j = j + 1;
                }
                
                result = std.Concat(result, params_str);
                result = std.Concat(result, ") -> ");
                mut ret_str := ast.serialize_type(sig.return_type, ctx);
                result = std.Concat(result, ret_str);
                result = std.Concat(result, "\n");
            }
            i = i + 1;
        }
    }
    return std.Clone(ctx, result);
}

func typechecker_serialize_type_environment(env: *TypeEnvironment[ctx], ctx: &Arena) str {
    mut result := typechecker_serialize_variables(env, ctx);
    result = std.Concat(result, typechecker_serialize_structures(env, ctx));
    result = std.Concat(result, typechecker_serialize_enums(env, ctx));
    result = std.Concat(result, typechecker_serialize_functions(env, ctx));
    return std.Clone(ctx, result);
}
