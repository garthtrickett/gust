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
            mut func_name := "";
            mut func_expr := ctx[expr.Call.function];
            if func_expr.tag == 0 { // Identifier
                func_name = func_expr.Identifier.name;
            } else {
                if func_expr.tag == 11 { // Selector
                    mut left_expr := ctx[func_expr.Selector.left];
                    if left_expr.tag == 0 {
                        func_name = std.Concat(left_expr.Identifier.name, ".");
                        func_name = std.Concat(func_name, func_expr.Selector.right);
                    }
                }
            }
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

func check_expression(expr_idx: Index[ast.Expression[ctx], ctx], env: *TypeEnvironment[ctx], scope: Index[Scope[ctx], ctx], ctx: &Arena) ast.Type[ctx] {
    unsafe {
        mut dummy: ast.Type[ctx];
        dummy.tag = 3; // Void
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return dummy;
        }
        mut expr := ctx[expr_idx];

        if expr.tag == 0 { // Identifier
            mut name := expr.Identifier.name;
            mut resolved_name := env_resolve_namespaced_ident(env, name, ctx);
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
            if alloc_t.tag == 7 { // Index
                mut t: ast.Type[ctx];
                t.tag = 8; // Struct
                t.Struct.struct_name = std.Clone(ctx, alloc_t.Index.struct_name);
                t.Struct.brand = alloc_t.Index.brand;
                return t;
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
            mut func_name := "";
            mut func_expr := ctx[expr.Call.function];
            if func_expr.tag == 0 { // Identifier
                func_name = func_expr.Identifier.name;
            } else {
                if func_expr.tag == 11 { // Selector
                    mut left_expr := ctx[func_expr.Selector.left];
                    if left_expr.tag == 0 {
                        func_name = std.Concat(left_expr.Identifier.name, ".");
                        func_name = std.Concat(func_name, func_expr.Selector.right);
                    }
                }
            }
            mut resolved_func := env_resolve_namespaced_ident(env, func_name, ctx);
            
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

            mut sig_lookup := (*env).function_registry.Get(resolved_func);
            if sig_lookup.Ok {
                return sig_lookup.Val.return_type;
            }
            mut t: ast.Type[ctx];
            t.tag = 0; // Int
            return t;
        }
        if expr.tag == 13 { // Empty
            return ctx[expr.Empty.target_type];
        }
        return dummy;
    }
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

func scope_new(parent: Index[Scope[ctx], ctx], ctx: &Arena) Index[Scope[ctx], ctx] {
    mut scope_idx: Index[Scope[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[scope_idx].parent = parent;
        ctx[scope_idx].bindings = std.HashMapNew(ctx);
    }
    return scope_idx;
}

func scope_insert(scope: Index[Scope[ctx], ctx], name: str, t: ast.Type[ctx], ctx: &Arena) {
    unsafe {
        ctx[scope].bindings.Insert(std.Clone(ctx, name), t);
    }
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
    function_registry: std.HashMap[str, FunctionSignature[ctx], ctx],
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

func env_new(ctx: &Arena) TypeEnvironment[ctx] {
    mut env_idx: Index[TypeEnvironment[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[env_idx].struct_registry = std.HashMapNew(ctx);
        ctx[env_idx].function_registry = std.HashMapNew(ctx);
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
}

func env_register_function(env: *TypeEnvironment[ctx], name: str, sig: FunctionSignature[ctx], ctx: &Arena) {
    unsafe {
        (*env).function_registry.Insert(std.Clone(ctx, name), sig);
    }
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
        } else {
            if t.tag == 8 { // Struct
                ctx[res_idx].Struct.struct_name = env_resolve_namespaced_ident(env, t.Struct.struct_name, ctx);
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
                            ctx[res_idx].Generic.name = env_resolve_namespaced_ident(env, t.Generic.name, ctx);
                            mut args_vec := &ctx[t.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
                            mut new_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
                            mut i := 0;
                            while i < len(*args_vec) {
                                mut arg := (*args_vec)[i];
                                new_args.Push(env_resolve_type(env, arg, ctx));
                                i = i + 1;
                            }
                            ctx[res_idx].Generic.args = os.ArenaAlloc(ctx);
                            mut dest_args := &ctx[ctx[res_idx].Generic.args] as *std.Vector[ast.Type[ctx], ctx];
                            *dest_args = new_args;
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
    if stmt.tag == 2 { // EnumDecl
        mut name := stmt.EnumDecl.name;
        mut namespaced_name := env_resolve_namespaced_ident(env, name, ctx);

        mut enum_layout: StructLayout[ctx];
        enum_layout.brand = empty[Index[str, ctx]];
        enum_layout.fields = std.HashMapNew(ctx);

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int
        enum_layout.fields.Insert(std.Clone(ctx, "tag"), t_int);

        unsafe {
            mut variants_vec := &ctx[stmt.EnumDecl.variants] as *std.Vector[ast.VariantDef[ctx], ctx];
            mut i := 0;
            while i < len(*variants_vec) {
                mut v := (*variants_vec)[i];
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
    unsafe {
        mut err: errors.CompilerError[ctx];
        err.kind.tag = kind_tag; // 2 for TypeError
        err.message = std.Clone(ctx, message);
        err.span = span;
        (*env).errors.Push(err);
    }
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
            if std.str_eq(expected.Index.struct_name, actual.Index.struct_name) {
                return 1;
            }
            return 0;
        }
        if expected.tag == 8 { // Struct
            if std.str_eq(expected.Struct.struct_name, actual.Struct.struct_name) {
                return 1;
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

            (*env).expected_return_type = return_type_idx;
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
                }
                if ctx[origs].map.len == 0 {
                    set_add(origs, name, ctx);
                }
                (*env).variable_origins.Insert(std.Clone(ctx, name), origs);
            } else {
                if var_type_idx != empty[Index[ast.Type[ctx], ctx]] {
                    mut origs := set_init(ctx);
                    set_add(origs, name, ctx);
                    (*env).variable_origins.Insert(std.Clone(ctx, name), origs);
                    mut resolved := env_resolve_type(env, ctx[var_type_idx], ctx);
                    val_type = resolved;
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
            } else {
                scope_insert(scope, name, val_type, ctx);
            }

            if val_type.tag == 8 { // Struct
                mut struct_name := val_type.Struct.struct_name;
                if len(struct_name) >= 7 && std.str_eq(std.str_slice(struct_name, 0, 7), "os_Dir_") {
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
                mut resolved_name := env_resolve_namespaced_ident(env, name, ctx);
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

            // Scratchpad storage restriction check
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
                    // Invalidate any active views that borrow from the root variable
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
                        mut struct_name := val_type.Struct.struct_name;
                        if len(struct_name) >= 7 && std.str_eq(std.str_slice(struct_name, 0, 7), "os_Dir_") {
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
                mut matched_variants := std.HashMapNew(ctx);

                mut i := 0;
                while i < len(*cases_vec) {
                    mut case := (*cases_vec)[i];
                    mut variant_name := case.variant_name;

                    matched_variants.Insert(std.Clone(ctx, variant_name), 1);

                    // Typecheck the case body in its own scope
                    mut parent_scope := scope;
                    mut parent_origins := (*env).variable_origins;

                    mut child_scope := scope_new(scope, ctx);

                    if len(case.fields) > 0 {
                        mut variant_struct_name := std.Concat(std.Concat(enum_name, "_"), variant_name);
                        mut lookup_variant := (*env).struct_registry.Get(variant_struct_name);
                        if lookup_variant.Ok {
                            mut fields_vec := &ctx[case.fields] as *std.Vector[str, ctx];
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

                    if case.body != empty[Index[ast.BlockStatement[ctx], ctx]] {
                        mut body := ctx[case.body];
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
