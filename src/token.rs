#[derive(Debug, PartialEq, Clone)]
pub enum TokenType {
    Eof,
    Illegal,

    // Identifiers + Literals
    Ident,
    Int,
    String, // Added for string literal views

    // Operators & Delimiters
    Assign,    // ":="
    Eq,        // "="
    Dot,       // "."
    Comma,     // ","
    Colon,     // ":"
    Semicolon, // ";"
    LParen,    // "("
    RParen,    // ")"
    LBrace,    // "{"
    RBrace,    // "}"
    LBracket,  // "["
    RBracket,  // "]"
    Ampersand, // "&"
    FatArrow,  // "=>"

    // Arithmetic & Comparisons
    Plus,
    Minus,
    Asterisk,
    Slash,
    EqEq,
    NotEq,
    Lt,
    Gt,

    // Keywords
    Mut,
    Func,
    Defer,
    Move,   // "move"
    Take,   // "take"
    While,  // "while"
    If,     // "if"
    Else,   // "else"
    As,     // "as"
    Unsafe, // "unsafe"
    Type,   // "type"
    Struct, // "struct"
    Enum,   // "enum"
    Match,  // "match"
    Return, // "return"
    Empty,  // "empty"
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub struct Position {
    pub line: usize,
    pub column: usize,
    pub offset: usize,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub struct Span {
    pub start: Position,
    pub end: Position,
}

impl Span {
    pub fn dummy() -> Self {
        Span {
            start: Position {
                line: 1,
                column: 1,
                offset: 0,
            },
            end: Position {
                line: 1,
                column: 1,
                offset: 0,
            },
        }
    }
}

#[derive(Debug, Clone)]
pub struct Token {
    pub token_type: TokenType,
    pub literal: String,
    pub span: Span,
}
