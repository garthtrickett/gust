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

func get_directory(path: str, ctx: &Arena) str {
    mut i := len(path) - 1;
    while i > 0 - 1 {
        mut b := std.str_byte_at(path, i);
        if b == 47 { // '/' is 47
            return std.str_slice(path, 0, i);
        }
        i = i - 1;
    }
    return ".";
}

func resolve_imports_recursive(
    file_path: str,
    graph: *std.Graph[str, resolveCtx],
    path_to_node: *std.HashMap[str, int, resolveCtx],
    resolveCtx: &Arena
) {
    mut lookup := path_to_node.Get(file_path);
    if lookup.Ok {
        return;
    }

    mut node_idx := graph.AddNode(file_path);
    path_to_node.Insert(file_path, node_idx);

    mut source := os.ReadFile(resolveCtx, file_path);
    if len(source) == 0 {
        return;
    }

    mut imports := scan_imports(source, resolveCtx);
    mut current_dir := get_directory(file_path, resolveCtx);

    mut i := 0;
    while i < len(imports) {
        mut imp := imports[i];
        mut joined_path := os_path_join(current_dir, imp, resolveCtx);

        resolve_imports_recursive(joined_path, graph, path_to_node, resolveCtx);

        mut imported_lookup := path_to_node.Get(joined_path);
        if imported_lookup.Ok {
            graph.AddEdge(node_idx, imported_lookup.Val);
        }

        i = i + 1;
    }
}
