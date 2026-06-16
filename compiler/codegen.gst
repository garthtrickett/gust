import "ast.gst" as ast;
import "token.gst" as token;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;

type Codegen[ctx] struct {
    env: &typechecker.TypeEnvironment[ctx]
}

func init_codegen(c: *Codegen[ctx], env: &typechecker.TypeEnvironment[ctx]) {
    unsafe {
        (*c).env = env;
    }
}

func codegen_get_c_type(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str { 
    unsafe {
        if t.tag == 0 { // Int
            return "int";
        }
        if t.tag == 1 { // Byte
            return "unsigned char";
        }
        if t.tag == 2 { // Bool
            return "unsigned char";
        }
        if t.tag == 3 { // Void
            return "void";
        }
        if t.tag == 4 { // Arena
            return "os_Arena";
        }
        if t.tag == 5 { // Str
            return "Slice_unsigned_char";
        }
        if t.tag == 6 { // Slice
            mut inner_type := ctx[t.Slice.inner];
            mut inner_ident := codegen_get_c_type_ident(inner_type, env, ctx);
            mut res := std.Concat("Slice_", inner_ident);
            return std.Clone(ctx, res);
        }
        if t.tag == 7 { // Index
            return "int";
        }
        if t.tag == 8 { // Struct
            return std.Clone(ctx, t.Struct.struct_name);
        }
        if t.tag == 9 { // RawPointer
            mut inner_type := ctx[t.RawPointer.inner];
            mut inner_c := codegen_get_c_type(inner_type, env, ctx);
            mut res := std.Concat(inner_c, "*");
            return std.Clone(ctx, res);
        }
        if t.tag == 10 { // Generic
            mut mono_name := codegen_get_monomorphized_name(t.Generic.name, t.Generic.args, env, ctx);
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
        mut args_vec := &ctx[args_idx] as *std.Vector[ast.Type[ctx], ctx];
        mut arg_names := "";
        mut i := 0;
        while i < len(*args_vec) {
            if i > 0 {
                arg_names = std.Concat(arg_names, "_");
            }
            mut arg_name := codegen_get_c_type_ident((*args_vec)[i], env, ctx);
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
        mut lookup_enum := env.enum_registry.Get(name);
        if lookup_enum.Ok {
            mut res := std.Concat("((", name);
            res = std.Concat(res, "){ .tag = 0 })");
            return std.Clone(ctx, res);
        }
        
        mut lookup_struct := env.struct_registry.Get(name);
        if lookup_struct.Ok {
            mut layout := lookup_struct.Val;
            mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
            if len(f_keys) == 0 {
                mut res := std.Concat("((", name);
                res = std.Concat(res, "){0})");
                return std.Clone(ctx, res);
            }
            
            mut fields_init := "";
            mut i := 0;
            while i < len(f_keys) {
                mut f_key := f_keys[i];
                mut f_lookup := layout.fields.Get(f_key);
                if f_lookup.Ok {
                    if i > 0 {
                        fields_init = std.Concat(fields_init, ", ");
                    }
                    mut f_init := codegen_gen_type_aware_initializer(f_lookup.Val, env, ctx);
                    mut field_assign := std.Concat(".", f_key);
                    field_assign = std.Concat(field_assign, " = ");
                    field_assign = std.Concat(field_assign, f_init);
                    fields_init = std.Concat(fields_init, field_assign);
                }
                i = i + 1;
            }
            
            mut res := std.Concat("((", name);
            res = std.Concat(res, "){ ");
            res = std.Concat(res, fields_init);
            res = std.Concat(res, " })");
            return std.Clone(ctx, res);
        }
        
        mut res := std.Concat("((", name);
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
            mut lookup := (*visited).Get(name);
            if lookup.Ok {
                return 0;
            }
            (*visited).Insert(std.Clone(ctx, name), 1);
            
            mut lookup_struct := env.struct_registry.Get(name);
            if lookup_struct.Ok {
                mut layout := lookup_struct.Val;
                mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
                mut i := 0;
                while i < len(f_keys) {
                    mut f_key := f_keys[i];
                    mut f_lookup := layout.fields.Get(f_key);
                    if f_lookup.Ok {
                        mut has_bool := codegen_has_boolean_fields_recursive(f_lookup.Val, env, visited, ctx);
                        if has_bool == 1 {
                            return 1;
                        }
                    }
                    i = i + 1;
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
        mut res := std.Concat("int ", struct_name);
        res = std.Concat(res, "_IsValid(");
        res = std.Concat(res, struct_name);
        res = std.Concat(res, "* req) {\n");
        res = std.Concat(res, "    if (req == NULL) return 0;\n");
        
        mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
        mut i := 0;
        while i < len(f_keys) {
            mut f_key := f_keys[i];
            mut f_lookup := layout.fields.Get(f_key);
            if f_lookup.Ok {
                mut f_type := f_lookup.Val;
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
            i = i + 1;
        }
        res = std.Concat(res, "    return 1;\n");
        res = std.Concat(res, "}\n");
        return std.Clone(ctx, res);
    }
}

func codegen_gen_type_aware_initializer(t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        if t.tag == 0 || t.tag == 1 || t.tag == 2 { // Int, Byte, Bool
            return "0";
        }
        if t.tag == 3 { // Void
            return "";
        }
        if t.tag == 4 { // Arena
            return "((os_Arena){0})";
        }
        if t.tag == 5 { // Str
            return "((Slice_unsigned_char){ NULL, 0 })";
        }
        if t.tag == 6 { // Slice
            mut inner_type := ctx[t.Slice.inner];
            mut inner_ident := codegen_get_c_type_ident(inner_type, env, ctx);
            mut res := std.Concat("((Slice_", inner_ident);
            res = std.Concat(res, "){ NULL, 0 })");
            return std.Clone(ctx, res);
        }
        if t.tag == 7 { // Index
            return "0xFFFFFFFF";
        }
        if t.tag == 9 { // RawPointer
            return "NULL";
        }
        if t.tag == 8 { // Struct
            return codegen_gen_struct_initializer(t.Struct.struct_name, env, ctx);
        }
        if t.tag == 10 { // Generic
            mut concrete_name := codegen_get_monomorphized_name(t.Generic.name, t.Generic.args, env, ctx);
            return codegen_gen_struct_initializer(concrete_name, env, ctx);
        }
    }
    return "0";
}
