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
            if len(name) >= 11 && std.str_eq(std.str_slice(name, 0, 11), "CastResult_") {
                return 1;
            }
            if len(name) >= 13 && std.str_eq(std.str_slice(name, 0, 13), "LookupResult_") {
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
            } else if func_expr.tag == 11 { // Selector
                mut left_expr := ctx[func_expr.Selector.left];
                if left_expr.tag == 0 {
                    func_name = std.Concat(left_expr.Identifier.name, ".");
                    func_name = std.Concat(func_name, func_expr.Selector.right);
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
            } else if t.tag == 8 { // Struct
                if t.Struct.brand != empty[Index[str, ctx]] {
                    mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                    brand_name = *brand_str_ptr;
                }
            }

            if !std.str_eq(brand_name, "") {
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
            return ctx[expr.AsCast.target_type];
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
            if left_t.tag == 8 { // Struct
                mut lookup_struct := (*env).struct_registry.Get(left_t.Struct.struct_name);
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
            } else if func_expr.tag == 11 { // Selector
                mut left_expr := ctx[func_expr.Selector.left];
                if left_expr.tag == 0 {
                    func_name = std.Concat(left_expr.Identifier.name, ".");
                    func_name = std.Concat(func_name, func_expr.Selector.right);
                }
            }
            mut resolved_func := env_resolve_namespaced_ident(env, func_name, ctx);
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
    return_type: ast.Type[ctx]
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
    errors: std.Vector[errors.CompilerError[ctx], ctx]
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
        } else if t.tag == 8 { // Struct
            ctx[res_idx].Struct.struct_name = env_resolve_namespaced_ident(env, t.Struct.struct_name, ctx);
        } else if t.tag == 9 { // RawPointer
            mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[inner_idx] = env_resolve_type(env, ctx[t.RawPointer.inner], ctx);
            ctx[res_idx].RawPointer.inner = inner_idx;
        } else if t.tag == 6 { // Slice
            mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[inner_idx] = env_resolve_type(env, ctx[t.Slice.inner], ctx);
            ctx[res_idx].Slice.inner = inner_idx;
        } else if t.tag == 10 { // Generic
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
        }

        env_register_function(env, namespaced_name, sig, ctx);
    }
}
