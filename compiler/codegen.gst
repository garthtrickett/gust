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

func codegen_generate_expression(expr_idx: Index[ast.Expression[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[ast.Expression[ctx], ctx]] {
            return "";
        }
        mut expr := ctx[expr_idx];
        if expr.tag == 0 { // Identifier
            if std.str_eq(expr.Identifier.name, "null") {
                return "0xFFFFFFFF";
            }
            return std.Clone(ctx, expr.Identifier.name);
        }
        if expr.tag == 1 { // Integer
            return std.Clone(ctx, std.FormatInt(expr.Integer.val));
        }
        if expr.tag == 2 { // String
            mut quote := '"';
            mut res := std.Concat(std.Format("%c", quote), expr.String.val);
            res = std.Concat(res, std.Format("%c", quote));
            mut len_str := std.FormatInt(len(expr.String.val));
            mut sl := std.Concat("((Slice_unsigned_char){ (unsigned char*)", res);
            sl = std.Concat(sl, ", ");
            sl = std.Concat(sl, len_str);
            sl = std.Concat(sl, " })");
            return std.Clone(ctx, sl);
        }
        if expr.tag == 3 { // Bool
            if expr.Bool.val == 1 {
                return "1";
            }
            return "0";
        }
        if expr.tag == 4 { // Move
            return codegen_generate_expression(expr.Move.expr, env, ctx);
        }
        if expr.tag == 5 { // Take
            return codegen_generate_expression(expr.Take.expr, env, ctx);
        }
        if expr.tag == 6 { // AddressOf
            mut inner := codegen_generate_expression(expr.AddressOf.expr, env, ctx);
            mut res := std.Concat("&(", inner);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if expr.tag == 7 { // Dereference
            mut inner := codegen_generate_expression(expr.Dereference.expr, env, ctx);
            mut res := std.Concat("(*(", inner);
            res = std.Concat(res, "))");
            return std.Clone(ctx, res);
        }
        if expr.tag == 8 { // IndexAccess
            mut alloc_str := codegen_generate_expression(expr.IndexAccess.allocator, env, ctx);
            mut index_str := codegen_generate_expression(expr.IndexAccess.index, env, ctx);
            mut res := std.Concat(alloc_str, "[");
            res = std.Concat(res, index_str);
            res = std.Concat(res, "]");
            return std.Clone(ctx, res);
        }
        if expr.tag == 9 { // AsCast
            mut left_str := codegen_generate_expression(expr.AsCast.left, env, ctx);
            mut target_type := ctx[expr.AsCast.target_type];
            mut target_str := codegen_get_c_type(target_type, env, ctx);
            mut res := std.Concat("((", target_str);
            res = std.Concat(res, ")");
            res = std.Concat(res, left_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if expr.tag == 10 { // Binary
            mut left_str := codegen_generate_expression(expr.Binary.left, env, ctx);
            mut right_str := codegen_generate_expression(expr.Binary.right, env, ctx);
            mut res := std.Concat("(", left_str);
            res = std.Concat(res, " ");
            res = std.Concat(res, expr.Binary.op);
            res = std.Concat(res, " ");
            res = std.Concat(res, right_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if expr.tag == 11 { // Selector
            mut left_str := codegen_generate_expression(expr.Selector.left, env, ctx);
            mut res := std.Concat(left_str, ".");
            res = std.Concat(res, expr.Selector.right);
            return std.Clone(ctx, res);
        }
        if expr.tag == 12 { // Call
            mut func_str := codegen_generate_expression(expr.Call.function, env, ctx);
            mut c_func := "";
            mut i := 0;
            while i < len(func_str) {
                mut b := std.str_byte_at(func_str, i);
                if b == 46 { // '.'
                    c_func = std.Concat(c_func, "_");
                } else {
                    mut char_slice := std.str_slice(func_str, i, i + 1);
                    c_func = std.Concat(c_func, char_slice);
                }
                i = i + 1;
            }
            
            mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
            mut args_str := "";
            mut j := 0;
            while j < len(*args_vec) {
                if j > 0 {
                    args_str = std.Concat(args_str, ", ");
                }
                mut arg_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[arg_idx] = (*args_vec)[j];
                mut arg_str := codegen_generate_expression(arg_idx, env, ctx);
                args_str = std.Concat(args_str, arg_str);
                j = j + 1;
            }
            mut res := std.Concat(c_func, "(");
            res = std.Concat(res, args_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if expr.tag == 13 { // Empty
            mut target_type := ctx[expr.Empty.target_type];
            return codegen_gen_type_aware_initializer(target_type, env, ctx);
        }
    }
    return "0";
}

func codegen_generate_statement(stmt_idx: Index[ast.Statement[ctx], ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        if stmt_idx == empty[Index[ast.Statement[ctx], ctx]] {
            return "";
        }
        mut stmt := ctx[stmt_idx];
        if stmt.tag == 4 { // VarDecl
            mut t_var := ctx[stmt.VarDecl.var_type];
            mut c_type := codegen_get_c_type(t_var, env, ctx);
            mut init_val := "";
            if stmt.VarDecl.value != empty[Index[ast.Expression[ctx], ctx]] {
                init_val = codegen_generate_expression(stmt.VarDecl.value, env, ctx);
            } else {
                init_val = codegen_gen_type_aware_initializer(t_var, env, ctx);
            }
            mut res := std.Concat("    ", c_type);
            res = std.Concat(res, " ");
            res = std.Concat(res, stmt.VarDecl.name);
            res = std.Concat(res, " = ");
            res = std.Concat(res, init_val);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if stmt.tag == 5 { // Assignment
            mut left_str := codegen_generate_expression(stmt.Assignment.left, env, ctx);
            mut val_str := codegen_generate_expression(stmt.Assignment.value, env, ctx);
            mut res := std.Concat("    ", left_str);
            res = std.Concat(res, " = ");
            res = std.Concat(res, val_str);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if stmt.tag == 12 { // Return
            mut expr_str := "";
            if stmt.Return.expr != empty[Index[ast.Expression[ctx], ctx]] {
                expr_str = codegen_generate_expression(stmt.Return.expr, env, ctx);
            }
            mut res := std.Concat("    return ", expr_str);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if stmt.tag == 13 { // Expression
            mut expr_str := codegen_generate_expression(stmt.Expression.expr, env, ctx);
            mut res := std.Concat("    ", expr_str);
            res = std.Concat(res, ";\n");
            return std.Clone(ctx, res);
        }
        if stmt.tag == 3 { // FunctionDecl
            mut t_ret := ctx[stmt.FunctionDecl.return_type];
            mut c_ret := codegen_get_c_type(t_ret, env, ctx);
            mut res := std.Concat(c_ret, " ");
            res = std.Concat(res, stmt.FunctionDecl.name);
            res = std.Concat(res, "(");
            
            mut params_vec := &ctx[stmt.FunctionDecl.params] as *std.Vector[ast.Parameter[ctx], ctx];
            mut params_str := "";
            mut i := 0;
            while i < len(*params_vec) {
                if i > 0 {
                    params_str = std.Concat(params_str, ", ");
                }
                mut p := (*params_vec)[i];
                mut p_c_type := codegen_get_c_type(p.param_type, env, ctx);
                mut p_decl := std.Concat(p_c_type, " ");
                p_decl = std.Concat(p_decl, p.name);
                params_str = std.Concat(params_str, p_decl);
                i = i + 1;
            }
            res = std.Concat(res, params_str);
            res = std.Concat(res, ") {\n");
            
            mut body := ctx[stmt.FunctionDecl.body];
            mut body_statements := &ctx[body.statements] as *std.Vector[ast.Statement[ctx], ctx];
            mut j := 0;
            while j < len(*body_statements) {
                mut child_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[child_stmt_idx] = (*body_statements)[j];
                mut child_c := codegen_generate_statement(child_stmt_idx, env, ctx);
                res = std.Concat(res, child_c);
                j = j + 1;
            }
            res = std.Concat(res, "}\n\n");
            return std.Clone(ctx, res);
        }
    }
    return "";
}

func codegen_generate(prog: *ast.Program[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) str {
    unsafe {
        mut c_code := "// Transpiled C Code\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <pthread.h>\n\n";
        
        // 1. Structures Declarations
        c_code = std.Concat(c_code, "// Structures\n");
        mut struct_keys := typechecker.typechecker_get_sorted_keys_layout(&(*env).struct_registry, ctx);
        mut i := 0;
        while i < len(struct_keys) {
            mut key := struct_keys[i];
            mut layout_lookup := (*env).struct_registry.Get(key);
            if layout_lookup.Ok {
                mut layout := layout_lookup.Val;
                mut struct_decl := std.Concat("typedef struct ", key);
                struct_decl = std.Concat(struct_decl, " ");
                struct_decl = std.Concat(struct_decl, key);
                struct_decl = std.Concat(struct_decl, ";\nstruct ");
                struct_decl = std.Concat(struct_decl, key);
                struct_decl = std.Concat(struct_decl, " {\n");
                
                mut f_keys := typechecker.typechecker_get_sorted_keys_type(&layout.fields, ctx);
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
                struct_decl = std.Concat(struct_decl, "};\n\n");
                c_code = std.Concat(c_code, struct_decl);
            }
            i = i + 1;
        }
        
        // 2. _IsValid Invariant Validator forward declarations
        c_code = std.Concat(c_code, "// Invariant Validator forward declarations\n");
        mut k := 0;
        while k < len(struct_keys) {
            mut key := struct_keys[k];
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
                c_code = std.Concat(c_code, decl);
            }
            k = k + 1;
        }
        c_code = std.Concat(c_code, "\n");
        
        // 3. _IsValid Invariant Validator implementations
        c_code = std.Concat(c_code, "// Invariant Validator implementations\n");
        mut m := 0;
        while m < len(struct_keys) {
            mut key := struct_keys[m];
            mut t_struct: ast.Type[ctx];
            t_struct.tag = 8; // Struct
            t_struct.Struct.struct_name = key;
            t_struct.Struct.brand = empty[Index[str, ctx]];
            
            mut has_bool := codegen_has_boolean_fields(t_struct, env, ctx);
            if has_bool == 1 {
                mut layout_lookup := (*env).struct_registry.Get(key);
                if layout_lookup.Ok {
                    mut impl := codegen_gen_is_valid_helper(key, layout_lookup.Val, env, ctx);
                    c_code = std.Concat(c_code, impl);
                    c_code = std.Concat(c_code, "\n");
                }
            }
            m = m + 1;
        }
        
        // 4. Statements in program (transpiled C)
        c_code = std.Concat(c_code, "// Program Statements\n");
        mut statements_vec := &ctx[(*prog).statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut s_idx := 0;
        while s_idx < len(*statements_vec) {
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[s_idx];
            mut stmt_c := codegen_generate_statement(stmt_idx, env, ctx);
            c_code = std.Concat(c_code, stmt_c);
            s_idx = s_idx + 1;
        }
        
        return std.Clone(ctx, c_code);
    }
}
