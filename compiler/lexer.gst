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

func new_lexer(input: str, ctx: &Arena) Lexer[ctx] {
    mut l: Lexer[ctx];
    l.input = input;
    l.position = 0;
    l.read_position = 0;
    l.ch = 0;
    l.line = 1;
    l.column = 1;
    read_char(&l);
    return l;
}
