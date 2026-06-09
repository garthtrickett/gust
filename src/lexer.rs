use crate::token::{Token, TokenType};

pub struct Lexer {
    input: Vec<char>,
    position: usize,
    read_position: usize,
    ch: char,
}

impl Lexer {
    pub fn new(input: &str) -> Self {
        let mut l = Lexer {
            input: input.chars().collect(),
            position: 0,
            read_position: 0,
            ch: '\0',
        };
        l.read_char();
        l
    }

    fn read_char(&mut self) {
        if self.read_position >= self.input.len() {
            self.ch = '\0';
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
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

        let tok = match self.ch {
            ':' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::Assign,
                        literal: ":=".to_string(),
                    }
                } else {
                    Token {
                        token_type: TokenType::Colon,
                        literal: ":".to_string(),
                    }
                }
            }
            '=' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::EqEq,
                        literal: "==".to_string(),
                    }
                } else {
                    Token {
                        token_type: TokenType::Eq,
                        literal: "=".to_string(),
                    }
                }
            }
            '!' => {
                if self.peek_char() == '=' {
                    self.read_char();
                    Token {
                        token_type: TokenType::NotEq,
                        literal: "!=".to_string(),
                    }
                } else {
                    Token {
                        token_type: TokenType::Illegal,
                        literal: self.ch.to_string(),
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
                    }
                }
            }
            ';' => Token {
                token_type: TokenType::Semicolon,
                literal: ";".to_string(),
            },
            '&' => Token {
                token_type: TokenType::Ampersand,
                literal: "&".to_string(),
            },
            '+' => Token {
                token_type: TokenType::Plus,
                literal: "+".to_string(),
            },
            '-' => Token {
                token_type: TokenType::Minus,
                literal: "-".to_string(),
            },
            '*' => Token {
                token_type: TokenType::Asterisk,
                literal: "*".to_string(),
            },
            '<' => Token {
                token_type: TokenType::Lt,
                literal: "<".to_string(),
            },
            '>' => Token {
                token_type: TokenType::Gt,
                literal: ">".to_string(),
            },
            '.' => Token {
                token_type: TokenType::Dot,
                literal: ".".to_string(),
            },
            ',' => Token {
                token_type: TokenType::Comma,
                literal: ",".to_string(),
            },
            '(' => Token {
                token_type: TokenType::LParen,
                literal: "(".to_string(),
            },
            ')' => Token {
                token_type: TokenType::RParen,
                literal: ")".to_string(),
            },
            '{' => Token {
                token_type: TokenType::LBrace,
                literal: "{".to_string(),
            },
            '}' => Token {
                token_type: TokenType::RBrace,
                literal: "}".to_string(),
            },
            '[' => Token {
                token_type: TokenType::LBracket,
                literal: "[".to_string(),
            },
            ']' => Token {
                token_type: TokenType::RBracket,
                literal: "]".to_string(),
            },
            '\0' => Token {
                token_type: TokenType::Eof,
                literal: "".to_string(),
            },
            '"' => {
                return Token {
                    token_type: TokenType::String,
                    literal: self.read_string(),
                };
            }
            c => {
                if is_letter(c) {
                    let literal = self.read_identifier();
                    let token_type = lookup_ident(&literal);
                    return Token {
                        token_type,
                        literal,
                    };
                } else if is_digit(c) {
                    let literal = self.read_number();
                    return Token {
                        token_type: TokenType::Int,
                        literal,
                    };
                } else {
                    Token {
                        token_type: TokenType::Illegal,
                        literal: c.to_string(),
                    }
                }
            }
        };

        self.read_char();
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
        "return" => TokenType::Return,
        _ => TokenType::Ident,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
            mut empty := "";
        "#;
        let mut l = Lexer::new(input);

        let expected = vec![
            (TokenType::Mut, "mut"),
            (TokenType::Ident, "msg"),
            (TokenType::Assign, ":="),
            (TokenType::String, "Hello World"),
            (TokenType::Semicolon, ";"),
            (TokenType::Mut, "mut"),
            (TokenType::Ident, "empty"),
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
}
