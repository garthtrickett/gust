import "ast.gst" as ast;

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
    imports: std.HashMap[str, str, ctx]
}

func env_new(ctx: &Arena) TypeEnvironment[ctx] {
    mut env: TypeEnvironment[ctx];
    env.struct_registry = std.HashMapNew(ctx);
    env.function_registry = std.HashMapNew(ctx);
    env.current_prefix = "";
    env.imports = std.HashMapNew(ctx);
    return env;
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
