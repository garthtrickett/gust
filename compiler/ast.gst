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
    body: BlockStatement[ctx],
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
        body: BlockStatement[ctx],
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
        body: BlockStatement[ctx],
        span: token.Span
    },
    If {
        condition: Index[Expression[ctx], ctx],
        consequence: BlockStatement[ctx],
        alternative: BlockStatement[ctx],
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
        else_body: BlockStatement[ctx],
        span: token.Span
    },
    UnsafeBlock {
        body: BlockStatement[ctx],
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
