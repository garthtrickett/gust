import "token.gst" as token;

type FieldDef[ctx] struct {
    name: str,
    field_type: Type[ctx],
    span: token.Span
}

type Parameter[ctx] struct {
    name: str,
    param_type: Type[ctx],
    span: token.Span
}

type VariantDef[ctx] struct {
    name: str,
    fields: Index[std.Vector[FieldDef[ctx], ctx], ctx],
    span: token.Span
}

type MatchCase[ctx] struct {
    variant_name: str,
    fields: Index[std.Vector[str, ctx], ctx],
    body: Index[BlockStatement[ctx], ctx],
    span: token.Span
}

type BlockStatement[ctx] struct {
    statements: Index[std.Vector[Statement[ctx], ctx], ctx],
    span: token.Span
}

type Type[ctx] enum {
    Int,
    Byte,
    Bool,
    Void,
    Arena,
    Str,
    Slice {
        inner: Index[Type[ctx], ctx]
    },
    Index {
        struct_name: str,
        brand: Index[str, ctx]
    },
    Struct {
        struct_name: str,
        brand: Index[str, ctx]
    },
    RawPointer {
        inner: Index[Type[ctx], ctx]
    },
    Generic {
        name: str,
        args: Index[std.Vector[Type[ctx], ctx], ctx]
    }
}

type Statement[ctx] enum {
    Import {
        path: str,
        alias: str,
        span: token.Span
    },
    StructDecl {
        name: str,
        generics: Index[std.Vector[str, ctx], ctx],
        fields: Index[std.Vector[FieldDef[ctx], ctx], ctx],
        span: token.Span
    },
    EnumDecl {
        name: str,
        generics: Index[std.Vector[str, ctx], ctx],
        variants: Index[std.Vector[VariantDef[ctx], ctx], ctx],
        span: token.Span
    },
    FunctionDecl {
        name: str,
        params: Index[std.Vector[Parameter[ctx], ctx], ctx],
        return_type: Index[Type[ctx], ctx],
        body: Index[BlockStatement[ctx], ctx],
        span: token.Span
    },
    VarDecl {
        name: str,
        is_mut: int,
        value: Index[Expression[ctx], ctx],
        var_type: Index[Type[ctx], ctx],
        span: token.Span
    },
    Assignment {
        left: Index[Expression[ctx], ctx],
        value: Index[Expression[ctx], ctx],
        span: token.Span
    },
    While {
        condition: Index[Expression[ctx], ctx],
        body: Index[BlockStatement[ctx], ctx],
        span: token.Span
    },
    If {
        condition: Index[Expression[ctx], ctx],
        consequence: Index[BlockStatement[ctx], ctx],
        alternative: Index[BlockStatement[ctx], ctx],
        span: token.Span
    },
    Match {
        expression: Index[Expression[ctx], ctx],
        cases: Index[std.Vector[MatchCase[ctx], ctx], ctx],
        span: token.Span
    },
    Guard {
        name: str,
        is_mut: int,
        value: Index[Expression[ctx], ctx],
        else_body: Index[BlockStatement[ctx], ctx],
        span: token.Span
    },
    UnsafeBlock {
        body: Index[BlockStatement[ctx], ctx],
        span: token.Span
    },
    Defer {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    Return {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    Expression {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    }
}

type Expression[ctx] enum {
    Identifier {
        name: str,
        span: token.Span
    },
    Integer {
        val: int,
        span: token.Span
    },
    String {
        val: str,
        span: token.Span
    },
    Bool {
        val: int,
        span: token.Span
    },
    Move {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    Take {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    AddressOf {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    Dereference {
        expr: Index[Expression[ctx], ctx],
        span: token.Span
    },
    IndexAccess {
        allocator: Index[Expression[ctx], ctx],
        index: Index[Expression[ctx], ctx],
        span: token.Span
    },
    AsCast {
        left: Index[Expression[ctx], ctx],
        target_type: Index[Type[ctx], ctx],
        is_reference: int,
        span: token.Span
    },
    Binary {
        op: str,
        left: Index[Expression[ctx], ctx],
        right: Index[Expression[ctx], ctx],
        span: token.Span
    },
    Selector {
        left: Index[Expression[ctx], ctx],
        right: str,
        span: token.Span
    },
    Call {
        function: Index[Expression[ctx], ctx],
        arguments: Index[std.Vector[Expression[ctx], ctx], ctx],
        span: token.Span
    },
    Empty {
        target_type: Index[Type[ctx], ctx],
        span: token.Span
    }
}

type Program[ctx] struct {
    statements: Index[std.Vector[Statement[ctx], ctx], ctx],
    span: token.Span
}

func ast_repeat_spaces(indent: int, ctx: &Arena) str {
    mut spaces := "";
    mut i := 0;
    while i < indent {
        spaces = std.Concat(spaces, "  ");
        i = i + 1;
    }
    return std.Clone(ctx, spaces);
}

func ast_join_strings(vec: std.Vector[str, ctx], sep: str, ctx: &Arena) str {
    mut result := "";
    mut i := 0;
    while i < len(vec) {
        if i > 0 {
            result = std.Concat(result, sep);
        }
        result = std.Concat(result, vec[i]);
        i = i + 1;
    }
    return std.Clone(ctx, result);
}

func serialize_type(t: Type[ctx], ctx: &Arena) str {
    unsafe {
        if t.tag == 0 { // Int
            return "Int";
        }
        if t.tag == 1 { // Byte
            return "Byte";
        }
        if t.tag == 2 { // Bool
            return "Bool";
        }
        if t.tag == 3 { // Void
            return "Void";
        }
        if t.tag == 4 { // Arena
            return "Arena";
        }
        if t.tag == 5 { // Str
            return "Str";
        }
        if t.tag == 6 { // Slice
            mut inner_str := serialize_type(ctx[t.Slice.inner], ctx);
            if std.str_eq(inner_str, "") == 1 { inner_str = "Unknown"; }
            mut res := std.Concat("Slice(", inner_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if t.tag == 7 { // Index
            mut quote := '"';
            mut struct_name := t.Index.struct_name;
            mut res := std.Concat("Index(", quote);
            res = std.Concat(res, struct_name);
            res = std.Concat(res, quote);
            if t.Index.brand == empty[Index[str, ctx]] {
                res = std.Concat(res, ", None)");
            } else {
                mut brand_str_ptr := &ctx[t.Index.brand] as *str;
                mut brand_str := *brand_str_ptr;
                res = std.Concat(res, ", Some(");
                res = std.Concat(res, quote);
                res = std.Concat(res, brand_str);
                res = std.Concat(res, quote);
                res = std.Concat(res, "))");
            }
            return std.Clone(ctx, res);
        }
        if t.tag == 8 { // Struct
            mut quote := '"';
            mut struct_name := t.Struct.struct_name;
            mut res := std.Concat("Struct(", quote);
            res = std.Concat(res, struct_name);
            res = std.Concat(res, quote);
            if t.Struct.brand == empty[Index[str, ctx]] {
                res = std.Concat(res, ", None)");
            } else {
                mut brand_str_ptr := &ctx[t.Struct.brand] as *str;
                mut brand_str := *brand_str_ptr;
                res = std.Concat(res, ", Some(");
                res = std.Concat(res, quote);
                res = std.Concat(res, brand_str);
                res = std.Concat(res, quote);
                res = std.Concat(res, "))");
            }
            return std.Clone(ctx, res);
        }
        if t.tag == 9 { // RawPointer
            mut inner_str := serialize_type(ctx[t.RawPointer.inner], ctx);
            mut res := std.Concat("RawPointer(", inner_str);
            res = std.Concat(res, ")");
            return std.Clone(ctx, res);
        }
        if t.tag == 10 { // Generic
            mut quote := '"';
            mut name := t.Generic.name;
            mut args_vec := &ctx[t.Generic.args] as *std.Vector[Type[ctx], ctx];
            mut arg_strs: std.Vector[str, ctx] := std.VectorNew(ctx);
            mut i := 0;
            while i < len(*args_vec) {
                mut arg_str := serialize_type((*args_vec)[i], ctx);
                arg_strs.Push(arg_str);
                i = i + 1;
            }
            mut joined := ast_join_strings(arg_strs, ", ", ctx);
            mut res := std.Concat("Generic(", quote);
            res = std.Concat(res, name);
            res = std.Concat(res, quote);
            res = std.Concat(res, ", [");
            res = std.Concat(res, joined);
            res = std.Concat(res, "])");
            return std.Clone(ctx, res);
        }
    }
    return "Unknown";
}

func ast_join_fields(fields: std.Vector[FieldDef[ctx], ctx], indent: int, ctx: &Arena) str {
    mut result := "";
    mut i := 0;
    while i < len(fields) {
        mut f := fields[i];
        mut pad := ast_repeat_spaces(indent, ctx);
        mut field_type_str := serialize_type(f.field_type, ctx);
        mut line := std.Concat(pad, "FieldDef: ");
        line = std.Concat(line, f.name);
        line = std.Concat(line, " : ");
        line = std.Concat(line, field_type_str);
        line = std.Concat(line, "\n");
        result = std.Concat(result, line);
        i = i + 1;
    }
    return std.Clone(ctx, result);
}

func ast_join_params(params: std.Vector[Parameter[ctx], ctx], indent: int, ctx: &Arena) str {
    mut result := "";
    mut i := 0;
    while i < len(params) {
        mut p := params[i];
        mut pad := ast_repeat_spaces(indent, ctx);
        mut param_type_str := serialize_type(p.param_type, ctx);
        mut line := std.Concat(pad, "Parameter: ");
        line = std.Concat(line, p.name);
        line = std.Concat(line, " : ");
        line = std.Concat(line, param_type_str);
        line = std.Concat(line, "\n");
        result = std.Concat(result, line);
        i = i + 1;
    }
    return std.Clone(ctx, result);
}

func serialize_expression(expr_idx: Index[Expression[ctx], ctx], indent: int, ctx: &Arena) str {
    unsafe {
        if expr_idx == empty[Index[Expression[ctx], ctx]] {
            return "";
        }
        mut expr := ctx[expr_idx];
        mut pad := ast_repeat_spaces(indent, ctx);

        if expr.tag == 0 { // Identifier
            mut res := std.Concat(pad, "Identifier: ");
            res = std.Concat(res, expr.Identifier.name);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
        if expr.tag == 1 { // Integer
            mut val_str := std.FormatInt(expr.Integer.val);
            mut res := std.Concat(pad, "Integer: ");
            res = std.Concat(res, val_str);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
        if expr.tag == 2 { // String
            mut quote := '"';
            mut res := std.Concat(pad, "String: ");
            res = std.Concat(res, quote);
            res = std.Concat(res, expr.String.val);
            res = std.Concat(res, quote);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
        if expr.tag == 3 { // Bool
            mut val_str := "false";
            if expr.Bool.val == 1 {
                val_str = "true";
            }
            mut res := std.Concat(pad, "Bool: ");
            res = std.Concat(res, val_str);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
        if expr.tag == 4 { // Move
            mut res := std.Concat(pad, "Move:\n");
            mut inner := serialize_expression(expr.Move.expr, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 5 { // Take
            mut res := std.Concat(pad, "Take:\n");
            mut inner := serialize_expression(expr.Take.expr, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 6 { // AddressOf
            mut res := std.Concat(pad, "AddressOf:\n");
            mut inner := serialize_expression(expr.AddressOf.expr, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 7 { // Dereference
            mut res := std.Concat(pad, "Dereference:\n");
            mut inner := serialize_expression(expr.Dereference.expr, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 8 { // IndexAccess
            mut res := std.Concat(pad, "IndexAccess:\n");
            mut alloc_str := serialize_expression(expr.IndexAccess.allocator, indent + 1, ctx);
            mut idx_str := serialize_expression(expr.IndexAccess.index, indent + 1, ctx);
            res = std.Concat(res, alloc_str);
            res = std.Concat(res, idx_str);
            return std.Clone(ctx, res);
        }
        if expr.tag == 9 { // AsCast
            mut target_type_str := serialize_type(ctx[expr.AsCast.target_type], ctx);
            mut ref_str := "false";
            if expr.AsCast.is_reference == 1 {
                ref_str = "true";
            }
            mut res := std.Concat(pad, "AsCast: ");
            res = std.Concat(res, target_type_str);
            res = std.Concat(res, " (ref=");
            res = std.Concat(res, ref_str);
            res = std.Concat(res, ")\n");
            mut inner := serialize_expression(expr.AsCast.left, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 10 { // Binary
            mut res := std.Concat(pad, "Binary: ");
            res = std.Concat(res, expr.Binary.op);
            res = std.Concat(res, "\n");
            mut left_str := serialize_expression(expr.Binary.left, indent + 1, ctx);
            mut right_str := serialize_expression(expr.Binary.right, indent + 1, ctx);
            res = std.Concat(res, left_str);
            res = std.Concat(res, right_str);
            return std.Clone(ctx, res);
        }
        if expr.tag == 11 { // Selector
            mut res := std.Concat(pad, "Selector: ");
            res = std.Concat(res, expr.Selector.right);
            res = std.Concat(res, "\n");
            mut inner := serialize_expression(expr.Selector.left, indent + 1, ctx);
            res = std.Concat(res, inner);
            return std.Clone(ctx, res);
        }
        if expr.tag == 12 { // Call
            mut res := std.Concat(pad, "Call:\n");
            mut func_str := serialize_expression(expr.Call.function, indent + 1, ctx);
            res = std.Concat(res, func_str);
            
            mut args_vec := &ctx[expr.Call.arguments] as *std.Vector[Expression[ctx], ctx];
            mut i := 0;
            while i < len(*args_vec) {
                mut arg_idx: Index[Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[arg_idx] = (*args_vec)[i];
                mut arg_str := serialize_expression(arg_idx, indent + 1, ctx);
                res = std.Concat(res, arg_str);
                i = i + 1;
            }
            return std.Clone(ctx, res);
        }
        if expr.tag == 13 { // Empty
            mut target_type_str := serialize_type(ctx[expr.Empty.target_type], ctx);
            mut res := std.Concat(pad, "Empty: ");
            res = std.Concat(res, target_type_str);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
    }
    return "UnknownExpr";
}

func serialize_block_statement(block_idx: Index[BlockStatement[ctx], ctx], indent: int, ctx: &Arena) str {
    unsafe {
        if block_idx == empty[Index[BlockStatement[ctx], ctx]] {
            return "";
        }
        mut block := ctx[block_idx];
        mut pad := ast_repeat_spaces(indent, ctx);
        mut res := std.Concat(pad, "BlockStatement:\n");
        
        mut statements_vec := &ctx[block.statements] as *std.Vector[Statement[ctx], ctx];
        mut i := 0;
        while i < len(*statements_vec) {
            mut stmt_idx: Index[Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[i];
            mut stmt_str := serialize_statement(stmt_idx, indent + 1, ctx);
            res = std.Concat(res, stmt_str);
            i = i + 1;
        }
        return std.Clone(ctx, res);
    }
}

func serialize_variant_def(v: VariantDef[ctx], indent: int, ctx: &Arena) str {
    unsafe {
        mut pad := ast_repeat_spaces(indent, ctx);
        mut res := std.Concat(pad, "VariantDef: ");
        res = std.Concat(res, v.name);
        res = std.Concat(res, "\n");
        
        mut fields_vec := &ctx[v.fields] as *std.Vector[FieldDef[ctx], ctx];
        mut fields_str := ast_join_fields(*fields_vec, indent + 1, ctx);
        res = std.Concat(res, fields_str);
        return std.Clone(ctx, res);
    }
}

func serialize_match_case(case_val: MatchCase[ctx], indent: int, ctx: &Arena) str {
    unsafe {
        mut pad := ast_repeat_spaces(indent, ctx);
        mut fields_vec := &ctx[case_val.fields] as *std.Vector[str, ctx];
        mut joined_fields := ast_join_strings(*fields_vec, ", ", ctx);
        
        mut res := std.Concat(pad, "MatchCase: ");
        res = std.Concat(res, case_val.variant_name);
        res = std.Concat(res, " [");
        res = std.Concat(res, joined_fields);
        res = std.Concat(res, "],\n");
        
        mut body_str := serialize_block_statement(case_val.body, indent + 1, ctx);
        res = std.Concat(res, body_str);
        return std.Clone(ctx, res);
    }
}

func serialize_statement(stmt_idx: Index[Statement[ctx], ctx], indent: int, ctx: &Arena) str {
    unsafe {
        if stmt_idx == empty[Index[Statement[ctx], ctx]] {
            return "";
        }
        mut stmt := ctx[stmt_idx];
        mut pad := ast_repeat_spaces(indent, ctx);

        if stmt.tag == 0 { // Import
            mut alias_str := stmt.Import.alias;
            if std.str_eq(alias_str, "") {
                alias_str = "<none>";
            }
            mut res := std.Concat(pad, "Import: ");
            res = std.Concat(res, stmt.Import.path);
            res = std.Concat(res, " as ");
            res = std.Concat(res, alias_str);
            res = std.Concat(res, "\n");
            return std.Clone(ctx, res);
        }
        if stmt.tag == 1 { // StructDecl
            mut generics_vec := &ctx[stmt.StructDecl.generics] as *std.Vector[str, ctx];
            mut joined_generics := ast_join_strings(*generics_vec, ", ", ctx);
            mut res := std.Concat(pad, "StructDecl: ");
            res = std.Concat(res, stmt.StructDecl.name);
            res = std.Concat(res, " <");
            res = std.Concat(res, joined_generics);
            res = std.Concat(res, ">\n");
            
            mut fields_vec := &ctx[stmt.StructDecl.fields] as *std.Vector[FieldDef[ctx], ctx];
            mut fields_str := ast_join_fields(*fields_vec, indent + 1, ctx);
            res = std.Concat(res, fields_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 2 { // EnumDecl
            mut generics_vec := &ctx[stmt.EnumDecl.generics] as *std.Vector[str, ctx];
            mut joined_generics := ast_join_strings(*generics_vec, ", ", ctx);
            mut res := std.Concat(pad, "EnumDecl: ");
            res = std.Concat(res, stmt.EnumDecl.name);
            res = std.Concat(res, " <");
            res = std.Concat(res, joined_generics);
            res = std.Concat(res, ">\n");
            
            mut variants_vec := &ctx[stmt.EnumDecl.variants] as *std.Vector[VariantDef[ctx], ctx];
            mut i := 0;
            while i < len(*variants_vec) {
                mut variant_str := serialize_variant_def((*variants_vec)[i], indent + 1, ctx);
                res = std.Concat(res, variant_str);
                i = i + 1;
            }
            return std.Clone(ctx, res);
        }
        if stmt.tag == 3 { // FunctionDecl
            mut return_type_str := serialize_type(ctx[stmt.FunctionDecl.return_type], ctx);
            mut res := std.Concat(pad, "FunctionDecl: ");
            res = std.Concat(res, stmt.FunctionDecl.name);
            res = std.Concat(res, " -> ");
            res = std.Concat(res, return_type_str);
            res = std.Concat(res, "\n");
            
            mut params_vec := &ctx[stmt.FunctionDecl.params] as *std.Vector[Parameter[ctx], ctx];
            mut params_str := ast_join_params(*params_vec, indent + 1, ctx);
            res = std.Concat(res, params_str);
            
            mut body_str := serialize_block_statement(stmt.FunctionDecl.body, indent + 1, ctx);
            res = std.Concat(res, body_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 4 { // VarDecl
            mut type_str := "<inferred>";
            if stmt.VarDecl.var_type != empty[Index[Type[ctx], ctx]] {
                type_str = serialize_type(ctx[stmt.VarDecl.var_type], ctx);
            }
            mut mut_str := "false";
            if stmt.VarDecl.is_mut == 1 {
                mut_str = "true";
            }
            mut res := std.Concat(pad, "VarDecl: ");
            res = std.Concat(res, stmt.VarDecl.name);
            res = std.Concat(res, " (mut=");
            res = std.Concat(res, mut_str);
            res = std.Concat(res, ") : ");
            res = std.Concat(res, type_str);
            res = std.Concat(res, "\n");
            
            if stmt.VarDecl.value != empty[Index[Expression[ctx], ctx]] {
                mut value_str := serialize_expression(stmt.VarDecl.value, indent + 1, ctx);
                res = std.Concat(res, value_str);
            }
            return std.Clone(ctx, res);
        }
        if stmt.tag == 5 { // Assignment
            mut res := std.Concat(pad, "Assignment:\n");
            mut left_str := serialize_expression(stmt.Assignment.left, indent + 1, ctx);
            mut val_str := serialize_expression(stmt.Assignment.value, indent + 1, ctx);
            res = std.Concat(res, left_str);
            res = std.Concat(res, val_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 6 { // While
            mut res := std.Concat(pad, "While:\n");
            mut cond_str := serialize_expression(stmt.While.condition, indent + 1, ctx);
            mut body_str := serialize_block_statement(stmt.While.body, indent + 1, ctx);
            res = std.Concat(res, cond_str);
            res = std.Concat(res, body_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 7 { // If
            mut res := std.Concat(pad, "If:\n");
            mut cond_str := serialize_expression(stmt.If.condition, indent + 1, ctx);
            mut cons_str := serialize_block_statement(stmt.If.consequence, indent + 1, ctx);
            res = std.Concat(res, cond_str);
            res = std.Concat(res, cons_str);
            
            if stmt.If.alternative != empty[Index[BlockStatement[ctx], ctx]] {
                res = std.Concat(res, pad);
                res = std.Concat(res, "Else:\n");
                mut alt_str := serialize_block_statement(stmt.If.alternative, indent + 1, ctx);
                res = std.Concat(res, alt_str);
            }
            return std.Clone(ctx, res);
        }
        if stmt.tag == 8 { // Match
            mut res := std.Concat(pad, "Match:\n");
            mut expr_str := serialize_expression(stmt.Match.expression, indent + 1, ctx);
            res = std.Concat(res, expr_str);
            
            mut cases_vec := &ctx[stmt.Match.cases] as *std.Vector[MatchCase[ctx], ctx];
            mut i := 0;
            while i < len(*cases_vec) {
                mut case_str := serialize_match_case((*cases_vec)[i], indent + 1, ctx);
                res = std.Concat(res, case_str);
                i = i + 1;
            }
            return std.Clone(ctx, res);
        }
        if stmt.tag == 9 { // Guard
            mut mut_str := "false";
            if stmt.Guard.is_mut == 1 {
                mut_str = "true";
            }
            mut res := std.Concat(pad, "Guard: ");
            res = std.Concat(res, stmt.Guard.name);
            res = std.Concat(res, " (mut=");
            res = std.Concat(res, mut_str);
            res = std.Concat(res, ")\n");
            
            mut val_str := serialize_expression(stmt.Guard.value, indent + 1, ctx);
            mut else_str := serialize_block_statement(stmt.Guard.else_body, indent + 1, ctx);
            res = std.Concat(res, val_str);
            res = std.Concat(res, else_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 10 { // UnsafeBlock
            mut res := std.Concat(pad, "UnsafeBlock:\n");
            mut body_str := serialize_block_statement(stmt.UnsafeBlock.body, indent + 1, ctx);
            res = std.Concat(res, body_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 11 { // Defer
            mut res := std.Concat(pad, "Defer:\n");
            mut expr_str := serialize_expression(stmt.Defer.expr, indent + 1, ctx);
            res = std.Concat(res, expr_str);
            return std.Clone(ctx, res);
        }
        if stmt.tag == 12 { // Return
            mut res := std.Concat(pad, "Return:\n");
            if stmt.Return.expr == empty[Index[Expression[ctx], ctx]] {
                mut void_pad := ast_repeat_spaces(indent + 1, ctx);
                res = std.Concat(res, void_pad);
                res = std.Concat(res, "<void>\n");
            } else {
                mut expr_str := serialize_expression(stmt.Return.expr, indent + 1, ctx);
                res = std.Concat(res, expr_str);
            }
            return std.Clone(ctx, res);
        }
        if stmt.tag == 13 { // Expression
            mut res := std.Concat(pad, "ExpressionStatement:\n");
            mut expr_str := serialize_expression(stmt.Expression.expr, indent + 1, ctx);
            res = std.Concat(res, expr_str);
            return std.Clone(ctx, res);
        }
    }
    return "UnknownStmt";
}

func serialize_program(prog: *Program[ctx], indent: int, ctx: &Arena) str {
    unsafe {
        mut pad := ast_repeat_spaces(indent, ctx);
        mut res := std.Concat(pad, "Program:\n");
        
        mut statements_vec := &ctx[(*prog).statements] as *std.Vector[Statement[ctx], ctx];
        mut i := 0;
        while i < len(*statements_vec) {
            mut stmt_idx: Index[Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[i];
            mut stmt_str := serialize_statement(stmt_idx, indent + 1, ctx);
            res = std.Concat(res, stmt_str);
            i = i + 1;
        }
        return std.Clone(ctx, res);
    }
}
