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

#[derive(Debug, Clone)]
pub struct Token {
    pub token_type: TokenType,
    pub literal: String,
}
