import "token.gst" as token;

type FieldDef[astCtx] struct {
    name: str,
    field_type: str,
    span: token.Span
}

type Parameter[astCtx] struct {
    name: str,
    param_type: str,
    span: token.Span
}

type VariantDef[astCtx] struct {
    name: str,
    fields: Index[std.Vector[FieldDef[astCtx], astCtx], astCtx],
    span: token.Span
}

type MatchCase[astCtx] struct {
    variant_name: str,
    fields: Index[std.Vector[str, astCtx], astCtx],
    body: Index[BlockStatement[astCtx], astCtx],
    span: token.Span
}

type BlockStatement[astCtx] struct {
    statements: Index[std.Vector[Index[Statement[astCtx], astCtx], astCtx], astCtx],
    span: token.Span
}

type Statement[astCtx] enum {
    Import {
        path: str,
        alias: str,
        span: token.Span
    },
    StructDecl {
        name: str,
        generics: Index[std.Vector[str, astCtx], astCtx],
        fields: Index[std.Vector[FieldDef[astCtx], astCtx], astCtx],
        span: token.Span
    },
    EnumDecl {
        name: str,
        generics: Index[std.Vector[str, astCtx], astCtx],
        variants: Index[std.Vector[VariantDef[astCtx], astCtx], astCtx],
        span: token.Span
    },
    FunctionDecl {
        name: str,
        params: Index[std.Vector[Parameter[astCtx], astCtx], astCtx],
        return_type: str,
        body: Index[BlockStatement[astCtx], astCtx],
        span: token.Span
    },
    VarDecl {
        name: str,
        is_mut: bool,
        value: Index[Expression[astCtx], astCtx],
        var_type: str,
        span: token.Span
    },
    Assignment {
        left: Index[Expression[astCtx], astCtx],
        value: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    While {
        condition: Index[Expression[astCtx], astCtx],
        body: Index[BlockStatement[astCtx], astCtx],
        span: token.Span
    },
    If {
        condition: Index[Expression[astCtx], astCtx],
        consequence: Index[BlockStatement[astCtx], astCtx],
        alternative: Index[BlockStatement[astCtx], astCtx],
        span: token.Span
    },
    Match {
        expression: Index[Expression[astCtx], astCtx],
        cases: Index[std.Vector[MatchCase[astCtx], astCtx], astCtx],
        span: token.Span
    },
    Guard {
        name: str,
        is_mut: bool,
        value: Index[Expression[astCtx], astCtx],
        else_body: Index[BlockStatement[astCtx], astCtx],
        span: token.Span
    },
    UnsafeBlock {
        body: Index[BlockStatement[astCtx], astCtx],
        span: token.Span
    },
    Defer {
        expr: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    Return {
        expr: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    Expression {
        expr: Index[Expression[astCtx], astCtx],
        span: token.Span
    }
}

type Expression[astCtx] enum {
    Identifier {
        name: str,
        span: token.Span
    },
    Integer {
        val: int,
        span: token.Span
    },
    StringVal {
        val: str,
        span: token.Span
    },
    BoolVal {
        val: bool,
        span: token.Span
    },
    Move {
        inner: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    Take {
        inner: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    AddressOf {
        inner: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    Dereference {
        inner: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    IndexAccess {
        allocator: Index[Expression[astCtx], astCtx],
        index: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    AsCast {
        left: Index[Expression[astCtx], astCtx],
        target_type: str,
        is_reference: bool,
        span: token.Span
    },
    Binary {
        op: str,
        left: Index[Expression[astCtx], astCtx],
        right: Index[Expression[astCtx], astCtx],
        span: token.Span
    },
    Selector {
        left: Index[Expression[astCtx], astCtx],
        right: str,
        span: token.Span
    },
    Call {
        function: Index[Expression[astCtx], astCtx],
        arguments: Index[std.Vector[Index[Expression[astCtx], astCtx], astCtx], astCtx],
        span: token.Span
    },
    Empty {
        target_type: str,
        span: token.Span
    }
}

type Program[astCtx] struct {
    statements: Index[std.Vector[Index[Statement[astCtx], astCtx], astCtx], astCtx],
    span: token.Span
}