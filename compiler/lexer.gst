import "token.gst" as token;

type Lexer[ctx] struct {
    input: str,
    position: int,
    read_position: int,
    ch: byte,
    line: int,
    column: int
}

func read_char(l: *Lexer[ctx]) {
    if l.ch == 10 {
        l.line = l.line + 1;
        l.column = 1;
    } else {
        if l.position > 0 {
            l.column = l.column + 1;
        } else { 
            if l.ch != 0 {
                l.column = l.column + 1;
            }
        }
    }

    mut input_len := len(l.input);
    if l.read_position == input_len {
        l.ch = 0;
    } else {
        if l.read_position > input_len {
            l.ch = 0;
        } else {
            l.ch = std.str_byte_at(l.input, l.read_position);
        }
    }
    l.position = l.read_position;
    l.read_position = l.read_position + 1;
}

func peek_char(l: *Lexer[ctx]) byte {
    mut input_len := len(l.input);
    if l.read_position == input_len {
        return 0;
    }
    if l.read_position > input_len {
        return 0;
    }
    return std.str_byte_at(l.input, l.read_position);
}

func skip_whitespace(l: *Lexer[ctx]) {
    while std.is_whitespace(l.ch) {
        read_char(l);
    }
}

func init_lexer(l: *Lexer[ctx], input: str) {
    l.input = input;
    l.position = 0;
    l.read_position = 0;
    l.ch = 0;
    l.line = 1;
    l.column = 1;
    read_char(l);
}

func is_letter(b: byte) bool {
    return std.is_alpha(b);
}

func is_digit(b: byte) bool {
    return std.is_digit(b);
}

func read_identifier(l: *Lexer[ctx]) str {
    mut start_pos := l.position;
    mut loop_active := 1;
    while loop_active == 1 {
        if is_letter(l.ch) {
            read_char(l);
        } else {
            if is_digit(l.ch) {
                read_char(l);
            } else {
                loop_active = 0;
            }
        }
    }
    return std.str_slice(l.input, start_pos, l.position);
}

func read_number(l: *Lexer[ctx]) str {
    mut start_pos := l.position;
    while is_digit(l.ch) {
        read_char(l);
    }
    return std.str_slice(l.input, start_pos, l.position);
}

func read_string(l: *Lexer[ctx]) str {
    mut start_pos := l.position + 1;
    mut loop_active := 1;
    while loop_active == 1 {
        read_char(l);
        if l.ch == 34 {
            loop_active = 0;
        } else {
            if l.ch == 0 {
                loop_active = 0;
            }
        }
    }
    mut out := std.str_slice(l.input, start_pos, l.position);
    read_char(l);
    return out;
}

func lookup_ident(literal: str) token.TokenType {
    mut t: token.TokenType;
    if std.str_eq(literal, "guard") { t.tag = 27; return t; }
    if std.str_eq(literal, "import") { t.tag = 28; return t; }
    if std.str_eq(literal, "mut") { t.tag = 29; return t; }
    if std.str_eq(literal, "func") { t.tag = 30; return t; }
    if std.str_eq(literal, "defer") { t.tag = 31; return t; }
    if std.str_eq(literal, "move") { t.tag = 32; return t; }
    if std.str_eq(literal, "take") { t.tag = 33; return t; }
    if std.str_eq(literal, "while") { t.tag = 34; return t; }
    if std.str_eq(literal, "if") { t.tag = 35; return t; }
    if std.str_eq(literal, "else") { t.tag = 36; return t; }
    if std.str_eq(literal, "as") { t.tag = 37; return t; }
    if std.str_eq(literal, "unsafe") { t.tag = 38; return t; }
    if std.str_eq(literal, "type") { t.tag = 39; return t; }
    if std.str_eq(literal, "struct") { t.tag = 40; return t; }
    if std.str_eq(literal, "enum") { t.tag = 41; return t; }
    if std.str_eq(literal, "match") { t.tag = 42; return t; }
    if std.str_eq(literal, "return") { t.tag = 43; return t; }
    if std.str_eq(literal, "empty") { t.tag = 44; return t; }
    if std.str_eq(literal, "bool") { t.tag = 45; return t; }
    if std.str_eq(literal, "true") { t.tag = 46; return t; }
    if std.str_eq(literal, "false") { t.tag = 47; return t; }
    
    t.tag = 2; // Ident
    return t;
}

func next_token(l: *Lexer[ctx], tok: *token.Token[ctx]) {
    skip_whitespace(l);

    mut start_pos: token.Position;
    start_pos.line = l.line;
    start_pos.column = l.column;
    start_pos.offset = l.position;

    mut tok_type: token.TokenType;

    if l.ch == 0 {
        tok_type.tag = 0;
        tok.token_type = tok_type;
        tok.literal = std.str_slice(l.input, start_pos.offset, l.position);
        mut end_pos: token.Position;
        end_pos.line = l.line;
        end_pos.column = l.column;
        end_pos.offset = l.position;
        tok.span.start = start_pos;
        tok.span.end = end_pos;
        return;
    }

    mut matched := 0;

    if l.ch == 58 {
        matched = 1;
        if peek_char(l) == 61 {
            read_char(l);
            tok_type.tag = 5;
        } else {
            tok_type.tag = 9;
        }
        read_char(l);
    }

    if matched == 0 {
        if l.ch == 61 {
            matched = 1;
            mut next := peek_char(l);
            if next == 61 {
                read_char(l);
                tok_type.tag = 23;
            } else {
                if next == 62 {
                    read_char(l);
                    tok_type.tag = 18;
                } else {
                    tok_type.tag = 6;
                }
            }
            read_char(l);
        }
    }

    if matched == 0 {
        if l.ch == 33 {
            matched = 1;
            if peek_char(l) == 61 {
                read_char(l);
                tok_type.tag = 24;
                read_char(l);
            } else {
                tok_type.tag = 1;
                read_char(l);
            }
        }
    }

    if matched == 0 {
        if l.ch == 47 {
            matched = 1;
            if peek_char(l) == 47 {
                read_char(l);
                mut loop_active := 1;
                while loop_active == 1 {
                    read_char(l);
                    if l.ch == 10 {
                        loop_active = 0;
                    } else {
                        if l.ch == 13 {
                            loop_active = 0;
                        } else {
                            if l.ch == 0 {
                                loop_active = 0;
                            }
                        }
                    }
                }
                next_token(l, tok);
                return;
            } else {
                tok_type.tag = 22;
                read_char(l);
            }
        }
    }

    if matched == 0 {
        if l.ch == 59 { matched = 1; tok_type.tag = 10; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 38 { matched = 1; tok_type.tag = 17; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 43 { matched = 1; tok_type.tag = 19; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 45 { matched = 1; tok_type.tag = 20; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 42 { matched = 1; tok_type.tag = 21; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 60 { matched = 1; tok_type.tag = 25; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 62 { matched = 1; tok_type.tag = 26; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 46 { matched = 1; tok_type.tag = 7; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 44 { matched = 1; tok_type.tag = 8; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 40 { matched = 1; tok_type.tag = 11; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 41 { matched = 1; tok_type.tag = 12; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 123 { matched = 1; tok_type.tag = 13; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 125 { matched = 1; tok_type.tag = 14; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 91 { matched = 1; tok_type.tag = 15; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 93 { matched = 1; tok_type.tag = 16; read_char(l); }
    }

    if matched == 0 {
        if l.ch == 34 {
            matched = 1;
            mut lit := read_string(l);
            tok_type.tag = 4;
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return;
        }
    }

    if matched == 0 {
        if is_letter(l.ch) {
            matched = 1;
            mut lit := read_identifier(l);
            tok_type = lookup_ident(lit);
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return;
        }
    }

    if matched == 0 {
        if is_digit(l.ch) {
            matched = 1;
            mut lit := read_number(l);
            tok_type.tag = 3;
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return;
        }
    }

    if matched == 0 {
        matched = 1;
        tok_type.tag = 1;
        read_char(l);
    }

    tok.token_type = tok_type;
    tok.literal = std.str_slice(l.input, start_pos.offset, l.position);
    mut end_pos: token.Position;
    end_pos.line = l.line;
    end_pos.column = l.column;
    end_pos.offset = l.position;
    tok.span.start = start_pos;
    tok.span.end = end_pos;
    return;
}

func next_token(l: *Lexer[ctx]) token.Token[ctx] {
    skip_whitespace(l);

    mut start_pos: token.Position;
    start_pos.line = l.line;
    start_pos.column = l.column;
    start_pos.offset = l.position;

    mut tok: token.Token[ctx];
    mut tok_type: token.TokenType;

    if l.ch == 0 {
        tok_type.tag = 0;
        tok.token_type = tok_type;
        tok.literal = std.str_slice(l.input, start_pos.offset, l.position);
        mut end_pos: token.Position;
        end_pos.line = l.line;
        end_pos.column = l.column;
        end_pos.offset = l.position;
        tok.span.start = start_pos;
        tok.span.end = end_pos;
        return tok;
    }

    mut matched := 0;

    if l.ch == 58 {
        matched = 1;
        if peek_char(l) == 61 {
            read_char(l);
            tok_type.tag = 5;
        } else {
            tok_type.tag = 9;
        }
        read_char(l);
    }

    if matched == 0 {
        if l.ch == 61 {
            matched = 1;
            mut next := peek_char(l);
            if next == 61 {
                read_char(l);
                tok_type.tag = 23;
            } else {
                if next == 62 {
                    read_char(l);
                    tok_type.tag = 18;
                } else {
                    tok_type.tag = 6;
                }
            }
            read_char(l);
        }
    }

    if matched == 0 {
        if l.ch == 33 {
            matched = 1;
            if peek_char(l) == 61 {
                read_char(l);
                tok_type.tag = 24;
                read_char(l);
            } else {
                tok_type.tag = 1;
                read_char(l);
            }
        }
    }

    if matched == 0 {
        if l.ch == 47 {
            matched = 1;
            if peek_char(l) == 47 {
                read_char(l);
                mut loop_active := 1;
                while loop_active == 1 {
                    read_char(l);
                    if l.ch == 10 {
                        loop_active = 0;
                    } else {
                        if l.ch == 13 {
                            loop_active = 0;
                        } else {
                            if l.ch == 0 {
                                loop_active = 0;
                            }
                        }
                    }
                }
                return next_token(l);
            } else {
                tok_type.tag = 22;
                read_char(l);
            }
        }
    }

    if matched == 0 {
        if l.ch == 59 { matched = 1; tok_type.tag = 10; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 38 { matched = 1; tok_type.tag = 17; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 43 { matched = 1; tok_type.tag = 19; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 45 { matched = 1; tok_type.tag = 20; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 42 { matched = 1; tok_type.tag = 21; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 60 { matched = 1; tok_type.tag = 25; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 62 { matched = 1; tok_type.tag = 26; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 46 { matched = 1; tok_type.tag = 7; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 44 { matched = 1; tok_type.tag = 8; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 40 { matched = 1; tok_type.tag = 11; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 41 { matched = 1; tok_type.tag = 12; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 123 { matched = 1; tok_type.tag = 13; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 125 { matched = 1; tok_type.tag = 14; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 91 { matched = 1; tok_type.tag = 15; read_char(l); }
    }
    if matched == 0 {
        if l.ch == 93 { matched = 1; tok_type.tag = 16; read_char(l); }
    }

    if matched == 0 {
        if l.ch == 34 {
            matched = 1;
            mut lit := read_string(l);
            tok_type.tag = 4;
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return tok;
        }
    }

    if matched == 0 {
        if is_letter(l.ch) {
            matched = 1;
            mut lit := read_identifier(l);
            tok_type = lookup_ident(lit);
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return tok;
        }
    }

    if matched == 0 {
        if is_digit(l.ch) {
            matched = 1;
            mut lit := read_number(l);
            tok_type.tag = 3;
            tok.token_type = tok_type;
            tok.literal = lit;
            mut end_pos: token.Position;
            end_pos.line = l.line;
            end_pos.column = l.column;
            end_pos.offset = l.position;
            tok.span.start = start_pos;
            tok.span.end = end_pos;
            return tok;
        }
    }

    if matched == 0 {
        matched = 1;
        tok_type.tag = 1;
        read_char(l);
    }

    tok.token_type = tok_type;
    tok.literal = std.str_slice(l.input, start_pos.offset, l.position);
    mut end_pos: token.Position;
    end_pos.line = l.line;
    end_pos.column = l.column;
    end_pos.offset = l.position;
    tok.span.start = start_pos;
    tok.span.end = end_pos;
    return tok;
}
