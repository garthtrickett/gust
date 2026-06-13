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
