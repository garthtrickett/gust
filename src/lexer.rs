use crate::token::{Token, TokenType};

pub struct Lexer {
    input: Vec<char>,
    position: usize,
    read_position: usize,
    ch: char,
    line: usize,
    column: usize,
}

impl Lexer {
    pub fn new(input: &str) -> Self {
        let mut l = Lexer {
            input: input.chars().collect(),
            position: 0,
            read_position: 0,
            ch: '\0',
            line: 1,
            column: 1,
        };
        l.read_char();
        l
    }

    fn read_char(&mut self) {
        if self.ch == '\n' {
            self.line += 1;
            self.column = 1;
        } else if self.position > 0 || (self.position == 0 && self.ch != '\0') {
            self.column += 1;
        }

        if self.read_position >= self.input.len() {
            self.ch = '\0';
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    fn current_position(&self) -> crate::token::Position {
        crate::token::Position {
            line: self.line,
            column: self.column,
            offset: self.position,
        }
    }

    fn peek_char(&self) -> char {
        if self.read_position >= self.input.len() {
            '\0'
        } else {
            self.input[self.read_position]
        }
    }

    fn skip_whitespace(&mut self) {
        while self.ch == ' ' || self.ch == '\t' || self.ch == '\n' || self.ch == '\r' {
            self.read_char();
        }
    }

    // Fixed: Now allows digits inside identifiers so 'ctx1' is not split into 'ctx' and '1'
    fn read_identifier(&mut self) -> String {
        let start_pos = self.position;
        while is_letter(self.ch) || is_digit(self.ch) {
            self.read_char();
        }
        self.input[start_pos..self.position].iter().collect()
    }

    fn read_number(&mut self) -> String {
        let start_pos = self.position;
        while is_digit(self.ch) {
            self.read_char();
        }
        self.input[start_pos..self.position].iter().collect()
    }

    fn read_string(&mut self) -> String {
        let start_pos = self.position + 1;
        loop {
            self.read_char();
            if self.ch == '"' || self.ch == '\0' {
                break;
            }
        }
        let out = self.input[start_pos..self.position].iter().collect();
        self.read_char(); // consume closing '"'
        out
    }

        pub fn next_token(&mut self) -> Token { 
        self.skip_whitespace();

        let start_pos = self.current_position();

        let mut tok = match self.ch {
            ':' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::Assign,
                        literal: ":=".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                } else {
                    Token {
                        token_type: TokenType::Colon,
                        literal: ":".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                }
            }
            '=' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::EqEq,
                        literal: "==".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                } else if self.peek_char() == '>' {
                    self.read_char();
                    Token {
                        token_type: TokenType::FatArrow,
                        literal: "=>".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                } else {
                    Token {
                        token_type: TokenType::Eq,
                        literal: "=".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                }
            }
            '!' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::NotEq,
                        literal: "!=".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                } else {
                    Token {
                        token_type: TokenType::Illegal,
                        literal: self.ch.to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                }
            }
            '/' => {
                if self.peek_char() == '/' {
                    while self.ch != '\n' && self.ch != '\r' && self.ch != '\0' {
                        self.read_char();
                    }
                    self.skip_whitespace();
                    return self.next_token();
                } else {
                    Token {
                        token_type: TokenType::Slash,
                        literal: "/".to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                }
            }
            ';' => Token {
                token_type: TokenType::Semicolon,
                literal: ";".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '&' => Token {
                token_type: TokenType::Ampersand,
                literal: "&".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '+' => Token {
                token_type: TokenType::Plus,
                literal: "+".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '-' => Token {
                token_type: TokenType::Minus,
                literal: "-".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '*' => Token {
                token_type: TokenType::Asterisk,
                literal: "*".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '<' => Token {
                token_type: TokenType::Lt,
                literal: "<".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '>' => Token {
                token_type: TokenType::Gt,
                literal: ">".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '.' => Token {
                token_type: TokenType::Dot,
                literal: ".".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            ',' => Token {
                token_type: TokenType::Comma,
                literal: ",".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '(' => Token {
                token_type: TokenType::LParen,
                literal: "(".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            ')' => Token {
                token_type: TokenType::RParen,
                literal: ")".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '{' => Token {
                token_type: TokenType::LBrace,
                literal: "{".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '}' => Token {
                token_type: TokenType::RBrace,
                literal: "}".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '[' => Token {
                token_type: TokenType::LBracket,
                literal: "[".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            ']' => Token {
                token_type: TokenType::RBracket,
                literal: "]".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '\0' => Token {
                token_type: TokenType::Eof,
                literal: "".to_string(),
                span: crate::token::Span { start: start_pos, end: start_pos },
            },
            '"' => {
                let literal = self.read_string();
                let end_pos = self.current_position();
                return Token {
                    token_type: TokenType::String,
                    literal,
                    span: crate::token::Span { start: start_pos, end: end_pos },
                };
            }
            c => {
                if is_letter(c) { 
                    let literal = self.read_identifier();
                    let token_type = lookup_ident(&literal);
                    let end_pos = self.current_position();
                    return Token {
                        token_type,
                        literal,
                        span: crate::token::Span { start: start_pos, end: end_pos },
                    };
                } else if is_digit(c) {
                    let literal = self.read_number();
                    let end_pos = self.current_position();
                    return Token {
                        token_type: TokenType::Int,
                        literal,
                        span: crate::token::Span { start: start_pos, end: end_pos },
                    };
                } else {
                    Token {
                        token_type: TokenType::Illegal,
                        literal: c.to_string(),
                        span: crate::token::Span { start: start_pos, end: start_pos },
                    }
                }
            }
        };

        self.read_char();
        tok.span.end = self.current_position();
        tok
    }
}

fn is_letter(ch: char) -> bool {
    ch.is_ascii_alphabetic() || ch == '_'
}

fn is_digit(ch: char) -> bool {
    ch.is_ascii_digit()
}

fn lookup_ident(ident: &str) -> TokenType {
    match ident {
        "import" => TokenType::Import,
        "mut" => TokenType::Mut,
        "func" => TokenType::Func,
        "defer" => TokenType::Defer,
        "move" => TokenType::Move,
        "take" => TokenType::Take,
        "while" => TokenType::While,
        "if" => TokenType::If,
        "else" => TokenType::Else,
        "as" => TokenType::As,
        "unsafe" => TokenType::Unsafe,
        "type" => TokenType::Type,
        "struct" => TokenType::Struct,
        "enum" => TokenType::Enum,
        "match" => TokenType::Match,
        "return" => TokenType::Return,
        "empty" => TokenType::Empty,
        "bool" => TokenType::Bool,
        "true" => TokenType::True,
        "false" => TokenType::False,
        _ => TokenType::Ident,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::token::Position;

    #[test]
    fn test_next_token_basic() {
        let input = "mut five := 5; func add(x: int, y: int) int { return x + y; }";
        let mut l = Lexer::new(input);

        let expected = vec![
            (TokenType::Mut, "mut"),
            (TokenType::Ident, "five"),
            (TokenType::Assign, ":="),
            (TokenType::Int, "5"),
            (TokenType::Semicolon, ";"),
            (TokenType::Func, "func"),
            (TokenType::Ident, "add"),
            (TokenType::LParen, "("),
            (TokenType::Ident, "x"),
            (TokenType::Colon, ":"),
            (TokenType::Ident, "int"),
            (TokenType::Comma, ","),
            (TokenType::Ident, "y"),
            (TokenType::Colon, ":"),
            (TokenType::Ident, "int"),
            (TokenType::RParen, ")"),
            (TokenType::Ident, "int"),
            (TokenType::LBrace, "{"),
            (TokenType::Return, "return"),
            (TokenType::Ident, "x"),
            (TokenType::Plus, "+"),
            (TokenType::Ident, "y"),
            (TokenType::Semicolon, ";"),
            (TokenType::RBrace, "}"),
            (TokenType::Eof, ""),
        ];

        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_identifiers_with_digits() {
        let input = "ctx1 ctx2 var_3 node_42";
        let mut l = Lexer::new(input);

        let expected = vec![
            (TokenType::Ident, "ctx1"),
            (TokenType::Ident, "ctx2"),
            (TokenType::Ident, "var_3"),
            (TokenType::Ident, "node_42"),
            (TokenType::Eof, ""),
        ];

        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_string_literals_and_comments() {
        let input = r#"
            // This is a comment
            mut msg := "Hello World"; // Trailing comment
            mut empty_val := "";
        "#;
        let mut l = Lexer::new(input);

        let expected = vec![
            (TokenType::Mut, "mut"),
            (TokenType::Ident, "msg"),
            (TokenType::Assign, ":="),
            (TokenType::String, "Hello World"),
            (TokenType::Semicolon, ";"),
            (TokenType::Mut, "mut"),
            (TokenType::Ident, "empty_val"),
            (TokenType::Assign, ":="),
            (TokenType::String, ""),
            (TokenType::Semicolon, ";"),
            (TokenType::Eof, ""),
        ];

        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_edge_cases() {
        let input = "\"unclosed string";
        let mut l = Lexer::new(input);
        let tok = l.next_token();
        assert_eq!(tok.token_type, TokenType::String);
        assert_eq!(tok.literal, "unclosed string");

        let tok_eof = l.next_token();
        assert_eq!(tok_eof.token_type, TokenType::Eof);
    }

    #[test]
    fn test_import_lexing() {
        let input = "import \"std\" as standard;";
        let mut l = Lexer::new(input);
        let expected = vec![
            (TokenType::Import, "import"),
            (TokenType::String, "std"),
            (TokenType::As, "as"),
            (TokenType::Ident, "standard"),
            (TokenType::Semicolon, ";"),
            (TokenType::Eof, ""),
        ];
        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_enum_and_match_lexing() {
        let input = "type Shape enum { Circle, Rectangle } match s { Circle => { return 1; } }";
        let mut l = Lexer::new(input);

        let expected = vec![
            (TokenType::Type, "type"),
            (TokenType::Ident, "Shape"),
            (TokenType::Enum, "enum"),
            (TokenType::LBrace, "{"),
            (TokenType::Ident, "Circle"),
            (TokenType::Comma, ","),
            (TokenType::Ident, "Rectangle"),
            (TokenType::RBrace, "}"),
            (TokenType::Match, "match"),
            (TokenType::Ident, "s"),
            (TokenType::LBrace, "{"),
            (TokenType::Ident, "Circle"),
            (TokenType::FatArrow, "=>"),
            (TokenType::LBrace, "{"),
            (TokenType::Return, "return"),
            (TokenType::Int, "1"),
            (TokenType::Semicolon, ";"),
            (TokenType::RBrace, "}"),
            (TokenType::RBrace, "}"),
            (TokenType::Eof, ""),
        ];

        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_empty_intrinsic_tokenizing() {
        let input = "empty[int]";
        let mut l = Lexer::new(input);
        let expected = vec![
            (TokenType::Empty, "empty"),
            (TokenType::LBracket, "["),
            (TokenType::Ident, "int"),
            (TokenType::RBracket, "]"),
            (TokenType::Eof, ""),
        ];
        for (expected_type, expected_literal) in expected {
            let tok = l.next_token();
            assert_eq!(tok.token_type, expected_type);
            assert_eq!(tok.literal, expected_literal);
        }
    }

    #[test]
    fn test_token_spans_and_position_tracking() {
        let input = "mut a := 10;\nmut b := 20;";
        let mut l = Lexer::new(input);

        // "mut" (line 1, column 1, offset 0 to line 1, column 4, offset 3)
        let tok1 = l.next_token();
        assert_eq!(tok1.token_type, TokenType::Mut);
        assert_eq!(tok1.literal, "mut");
        assert_eq!(
            tok1.span.start,
            Position {
                line: 1,
                column: 1,
                offset: 0
            }
        );
        assert_eq!(
            tok1.span.end,
            Position {
                line: 1,
                column: 4,
                offset: 3
            }
        );

        // "a" (line 1, column 5, offset 4 to line 1, column 6, offset 5)
        let tok2 = l.next_token();
        assert_eq!(tok2.token_type, TokenType::Ident);
        assert_eq!(tok2.literal, "a");
        assert_eq!(
            tok2.span.start,
            Position {
                line: 1,
                column: 5,
                offset: 4
            }
        );
        assert_eq!(
            tok2.span.end,
            Position {
                line: 1,
                column: 6,
                offset: 5
            }
        );

        // ":=" (line 1, column 7, offset 6 to line 1, column 9, offset 8)
        let tok3 = l.next_token();
        assert_eq!(tok3.token_type, TokenType::Assign);
        assert_eq!(tok3.literal, ":=");
        assert_eq!(
            tok3.span.start,
            Position {
                line: 1,
                column: 7,
                offset: 6
            }
        );
        assert_eq!(
            tok3.span.end,
            Position {
                line: 1,
                column: 9,
                offset: 8
            }
        );

        // "10" (line 1, column 10, offset 9 to line 1, column 12, offset 11)
        let tok4 = l.next_token();
        assert_eq!(tok4.token_type, TokenType::Int);
        assert_eq!(tok4.literal, "10");
        assert_eq!(
            tok4.span.start,
            Position {
                line: 1,
                column: 10,
                offset: 9
            }
        );
        assert_eq!(
            tok4.span.end,
            Position {
                line: 1,
                column: 12,
                offset: 11
            }
        );

        // ";" (line 1, column 12, offset 11 to line 1, column 13, offset 12)
        let tok5 = l.next_token();
        assert_eq!(tok5.token_type, TokenType::Semicolon);
        assert_eq!(tok5.literal, ";");
        assert_eq!(
            tok5.span.start,
            Position {
                line: 1,
                column: 12,
                offset: 11
            }
        );
        assert_eq!(
            tok5.span.end,
            Position {
                line: 1,
                column: 13,
                offset: 12
            }
        );

        // "mut" (line 2, column 1, offset 13 to line 2, column 4, offset 16)
        let tok6 = l.next_token();
        assert_eq!(tok6.token_type, TokenType::Mut);
        assert_eq!(tok6.literal, "mut");
        assert_eq!(
            tok6.span.start,
            Position {
                line: 2,
                column: 1,
                offset: 13
            }
        );
        assert_eq!(
            tok6.span.end,
            Position {
                line: 2,
                column: 4,
                offset: 16
            }
        );
    }
}
