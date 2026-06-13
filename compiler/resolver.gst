import "token.gst" as token;
import "lexer.gst" as lexer;

func scan_imports(source: str, ctx: &Arena) std.Vector[str, ctx] {
    mut paths: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, source);

    mut loop_active := 1;
    while loop_active == 1 {
        mut t: token.Token[ctx];
        lexer.next_token(&l, &t);

        if t.token_type.tag == 28 { // TokenType::Import = 28
            lexer.next_token(&l, &t);
            
            mut has_path := 0;
            mut path_str := "";
            
            if t.token_type.tag == 4 { // TokenType::String = 4 (e.g. "std")
                path_str = t.literal;
                has_path = 1;
            } else {
                if t.token_type.tag == 1 { // TokenType::Illegal = 1 (e.g. ')
                    lexer.next_token(&l, &t);
                    if t.token_type.tag == 2 { // TokenType::Ident = 2
                        path_str = t.literal;
                        has_path = 1;
                        lexer.next_token(&l, &t); // Consume closing '
                    }
                }
            }
            
            if has_path == 1 {
                paths.Push(path_str);

                lexer.next_token(&l, &t);
                if t.token_type.tag == 37 { // TokenType::As = 37
                    lexer.next_token(&l, &t);
                    if t.token_type.tag == 2 { // TokenType::Ident = 2
                        lexer.next_token(&l, &t);
                        if t.token_type.tag == 10 { // TokenType::Semicolon = 10
                            // Semicolon consumed, continue
                        } else {
                            loop_active = 0;
                        }
                    } else {
                        loop_active = 0;
                    }
                } else {
                    if t.token_type.tag == 10 { // TokenType::Semicolon = 10
                        // Semicolon consumed, continue
                    } else {
                        loop_active = 0;
                    }
                }
            } else {
                loop_active = 0;
            }
        } else {
            loop_active = 0;
        }
    }

    return paths;
}
