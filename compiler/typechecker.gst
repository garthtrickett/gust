import "ast.gst" as ast;

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

func set_contains(set: Index[OriginSet[ctx], ctx], element: str, ctx: &Arena) bool {
    unsafe {
        return ctx[set].map.Get(element).Ok == 1;
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
    open_directories: std.HashMap[str, int, ctx]
}

func env_new(ctx: &Arena) TypeEnvironment[ctx] {
    mut env_idx: Index[TypeEnvironment[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[env_idx].struct_registry = std.HashMapNew(ctx);
        ctx[env_idx].function_registry = std.HashMapNew(ctx);
        ctx[env_idx].current_prefix = "";
        ctx[env_idx].imports = std.HashMapNew(ctx);
        ctx[env_idx].variable_origins = std.HashMapNew(ctx);
        ctx[env_idx].moved_vars = std.HashMapNew(ctx);
        ctx[env_idx].open_directories = std.HashMapNew(ctx);
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
