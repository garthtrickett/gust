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
