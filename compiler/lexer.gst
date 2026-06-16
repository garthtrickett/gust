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
    unsafe {
        if (*l).ch == 10 { // '\n' = 10
            (*l).line = (*l).line + 1;
            (*l).column = 1;
        } else {
            if (*l).position > 0 {
                (*l).column = (*l).column + 1;
            } else {
                if (*l).position == 0 {
                    if (*l).ch != 0 {
                        (*l).column = (*l).column + 1;
                    }
                }
            }
        }

        if (*l).read_position >= len((*l).input) {
            (*l).ch = 0;
        } else {
            (*l).ch = std.str_byte_at((*l).input, (*l).read_position);
        }
        (*l).position = (*l).read_position;
        (*l).read_position = (*l).read_position + 1;
    }
}

func init_lexer(l: *Lexer[ctx], input: str) {
    unsafe {
        (*l).input = input;
        (*l).position = 0;
        (*l).read_position = 0;
        (*l).ch = 0;
        (*l).line = 1;
        (*l).column = 1;
        read_char(l);
    }
}

func peek_char(l: *Lexer[ctx]) byte {
    unsafe {
        if (*l).read_position >= len((*l).input) {
            return 0;
        }
        return std.str_byte_at((*l).input, (*l).read_position);
    }
}

func skip_whitespace(l: *Lexer[ctx]) {
    unsafe {
        while std.is_whitespace((*l).ch) {
            read_char(l);
        }
    }
}

func is_letter(b: byte) bool {
    return std.is_alpha(b);
}

func is_digit(b: byte) bool {
    return std.is_digit(b);
}

func read_identifier(l: *Lexer[ctx]) str {
    unsafe {
        mut start_pos := (*l).position;
        while is_letter((*l).ch) || is_digit((*l).ch) {
            read_char(l);
        }
        return std.str_slice((*l).input, start_pos, (*l).position);
    }
}

func read_number(l: *Lexer[ctx]) str {
    unsafe {
        mut start_pos := (*l).position;
        while is_digit((*l).ch) {
            read_char(l);
        }
        return std.str_slice((*l).input, start_pos, (*l).position);
    }
}

func read_string(l: *Lexer[ctx]) str {
    unsafe {
        mut delimiter := (*l).ch;
        if delimiter == 0 {
            delimiter = 34; // Fallback to '"'
        }
        
        mut start_pos := (*l).position + 1;
        mut loop := 1;
        while loop == 1 {
            read_char(l);
            if (*l).ch == 92 { // '\' = 92
                read_char(l); // skip the escaped character
            } else {
                if (*l).ch == delimiter {
                    loop = 0;
                } else {
                    if (*l).ch == 0 { // EOF
                        loop = 0;
                    }
                }
            }
        }
        mut out := std.str_slice((*l).input, start_pos, (*l).position);
        read_char(l); // consume closing delimiter
        return out;
    }
}

func lookup_ident(literal: str) token.TokenType {
    mut t: token.TokenType;
    t.tag = 2; // Default TokenType::Ident
    
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
    
    return t;
}

func current_position(l: *Lexer[ctx]) token.Position {
    mut pos: token.Position;
    unsafe {
        pos.line = (*l).line;
        pos.column = (*l).column;
        pos.offset = (*l).position;
    }
    return pos;
}

func next_token(l: *Lexer[ctx], tok: *token.Token[ctx]) {
    skip_whitespace(l);
    
    mut start_pos := current_position(l);
    
    unsafe {
        mut t_type: token.TokenType;
        t_type.tag = 1; // Default TokenType::Illegal
        
        mut literal := "";
        
        if (*l).ch == 58 { // ':'
            if peek_char(l) == 61 { // '='
                read_char(l);
                t_type.tag = 5; // Assign
                literal = ":=";
            } else {
                t_type.tag = 9; // Colon
                literal = ":";
            }
            read_char(l);
        } else if (*l).ch == 61 { // '='
            if peek_char(l) == 61 { // '='
                read_char(l);
                t_type.tag = 23; // EqEq
                literal = "==";
            } else if peek_char(l) == 62 { // '>'
                read_char(l);
                t_type.tag = 18; // FatArrow
                literal = "=>";
            } else {
                t_type.tag = 6; // Eq
                literal = "=";
            }
            read_char(l);
        } else if (*l).ch == 33 { // '!'
            if peek_char(l) == 61 { // '='
                read_char(l);
                t_type.tag = 24; // NotEq
                literal = "!=";
            } else {
                t_type.tag = 1; // Illegal
                literal = "!";
            }
            read_char(l);
        } else if (*l).ch == 47 { // '/'
            if peek_char(l) == 47 { // '/'
                while (*l).ch != 10 && (*l).ch != 13 && (*l).ch != 0 {
                    read_char(l);
                }
                skip_whitespace(l);
                next_token(l, tok);
                return;
            } else {
                t_type.tag = 22; // Slash
                literal = "/";
                read_char(l);
            }
        } else if (*l).ch == 59 { // ';'
            t_type.tag = 10; // Semicolon
            literal = ";";
            read_char(l);
        } else if (*l).ch == 38 { // '&'
            if peek_char(l) == 38 { // '&'
                read_char(l);
                t_type.tag = 50; // AmpAmp
                literal = "&&";
            } else {
                t_type.tag = 17; // Ampersand
                literal = "&";
            }
            read_char(l);
        } else if (*l).ch == 124 { // '|'
            if peek_char(l) == 124 { // '|'
                read_char(l);
                t_type.tag = 51; // PipePipe
                literal = "||";
            } else {
                t_type.tag = 1; // Illegal
                literal = "|";
            }
            read_char(l);
        } else if (*l).ch == 43 { // '+'
            t_type.tag = 19; // Plus
            literal = "+";
            read_char(l);
        } else if (*l).ch == 45 { // '-'
            t_type.tag = 20; // Minus
            literal = "-";
            read_char(l);
        } else if (*l).ch == 42 { // '*'
            t_type.tag = 21; // Asterisk
            literal = "*";
            read_char(l);
        } else if (*l).ch == 60 { // '<'
            if peek_char(l) == 61 { // '='
                read_char(l);
                t_type.tag = 48; // LtEq
                literal = "<=";
            } else {
                t_type.tag = 25; // Lt
                literal = "<";
            }
            read_char(l);
        } else if (*l).ch == 62 { // '>'
            if peek_char(l) == 61 { // '='
                read_char(l);
                t_type.tag = 49; // GtEq
                literal = ">=";
            } else {
                t_type.tag = 26; // Gt
                literal = ">";
            }
            read_char(l);
        } else if (*l).ch == 46 { // '.'
            t_type.tag = 7; // Dot
            literal = ".";
            read_char(l);
        } else if (*l).ch == 44 { // ','
            t_type.tag = 8; // Comma
            literal = ",";
            read_char(l);
        } else if (*l).ch == 40 { // '('
            t_type.tag = 11; // LParen
            literal = "(";
            read_char(l);
        } else if (*l).ch == 41 { // ')'
            t_type.tag = 12; // RParen
            literal = ")";
            read_char(l);
        } else if (*l).ch == 123 { // '{'
            t_type.tag = 13; // LBrace
            literal = "{";
            read_char(l);
        } else if (*l).ch == 125 { // '}'
            t_type.tag = 14; // RBrace
            literal = "}";
            read_char(l);
        } else if (*l).ch == 91 { // '['
            t_type.tag = 15; // LBracket
            literal = "[";
            read_char(l);
        } else if (*l).ch == 93 { // ']'
            t_type.tag = 16; // RBracket
            literal = "]";
            read_char(l);
        } else if (*l).ch == 0 { // '\0'
            t_type.tag = 0; // Eof
            literal = "";
        } else if (*l).ch == 34 { // '"'
            literal = read_string(l);
            t_type.tag = 4; // String
        } else if (*l).ch == 39 { // '\''
            literal = read_string(l);
            t_type.tag = 4; // String
        } else {
            if is_letter((*l).ch) {
                literal = read_identifier(l);
                t_type = lookup_ident(literal);
            } else if is_digit((*l).ch) {
                literal = read_number(l);
                t_type.tag = 3; // Int
            } else {
                literal = "illegal";
                t_type.tag = 1; // Illegal
                read_char(l);
            }
        }
        
        (*tok).token_type = t_type;
        (*tok).literal = literal;
        (*tok).span.start = start_pos;
        (*tok).span.end = current_position(l);
    }
}
