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
            '"' => Token {
                token_type: TokenType::String,
                literal: self.read_string(),
            },
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
        _ => TokenType::Ident,
    }
}
