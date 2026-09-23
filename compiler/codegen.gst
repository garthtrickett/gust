// Patch 25.10: THIS FILE NO LONGER GENERATES CODE.
//
// It held the bootstrap C emitter -- 4,833 lines, 60 functions -- and the
// emitter is deleted with its entry, because they existed only for each
// other. What is left is the 7 functions the NATIVE route calls, measured
// rather than guessed: compiler/mir_native_backend_full_program_source.gst
// uses codegen_erase_type, codegen_get_erased_struct_name,
// codegen_get_expression_span, codegen_get_expression_type and
// codegen_resource_cleanup_c_function_name, which reach
// codegen_erase_struct_name and codegen_is_brand_type between them.
//
// 49 functions were reachable only from codegen_generate; 4 more were
// reachable from neither root and were named only by the two emitter test
// entries that go with it. 53 deleted, 4,547 lines.
//
// THE NAME IS NOW WRONG and is left wrong on purpose. Renaming moves every
// importer and belongs in its own patch; a rename buried in a 4,500-line
// deletion is a rename nobody can review. What this file actually is: type
// erasure and expression metadata for the native backend.

// Gone with the emitter and checked before removing, not assumed: the
// errors.gst, mir_function_abi_authority.gst and mir_function_call.gst
// imports, and the Codegen and CodegenStringHeader types. The only
// external reference to either type was
// compiler/codegen_initializer_test_entry.gst, which is an emitter test
// and is deleted with the emitter.
import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

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
