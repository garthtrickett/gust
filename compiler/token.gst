type TokenType enum {
    Eof,
    Illegal,
    Ident,
    Int,
    String,
    Assign,
    Eq,
    Dot,
    Comma,
    Colon,
    Semicolon,
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Ampersand,
    FatArrow,
    Plus,
    Minus,
    Asterisk,
    Slash,
    EqEq,
    NotEq,
    Lt,
    Gt,
    Guard,
    Import,
    Mut,
    Func,
    Defer,
    Move,
    Take,
    While,
    If,
    Else,
    As,
    Unsafe,
    Type,
    Struct,
    Enum,
    Match,
    Return,
    Empty,
    Bool,
    True,
    False
}

type Position struct {
    line: int,
    column: int,
    offset: int
}

type Span struct {
    start: Position,
    end: Position
}

type Token[ctx] struct {
    token_type: TokenType,
    literal: str,
    span: Span
}
type Position struct {
    line: int,
    column: int,
    offset: int
}

type Span struct {
    start: Position,
    end: Position
}

type TokenType enum {
    Eof,
    Illegal,

    Ident,
    Int,
    String,

    Assign,
    Eq,
    Dot,
    Comma,
    Colon,
    Semicolon,
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Ampersand,
    FatArrow,

    Plus,
    Minus,
    Asterisk,
    Slash,
    EqEq,
    NotEq,
    Lt,
    Gt,

    Guard,
    Import,
    Mut,
    Func,
    Defer,
    Move,
    Take,
    While,
    If,
    Else,
    As,
    Unsafe,
    Type,
    Struct,
    Enum,
    Match,
    Return,
    Empty,
    Bool,
    True,
    False
}

type Token[ctx] struct {
    token_type: TokenType,
    literal: str,
    span: Span
}
