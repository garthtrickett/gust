import "token.gst" as token;
import "lexer.gst" as lexer;

func scan_imports(source: str, ctx: &Arena) std.Vector[str, ctx] {
    mut paths: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, source);

    mut loop_active := 1;
    mut t: token.Token[ctx];
    lexer.next_token(&l, &t);

    while loop_active == 1 {
        if t.token_type.tag != 28 { // TokenType::Import = 28
            if t.token_type.tag == 10 { // TokenType::Semicolon = 10
                lexer.next_token(&l, &t);
            } else {
                loop_active = 0;
            }
        } else {
            mut path_tok: token.Token[ctx];
            lexer.next_token(&l, &path_tok);
            
            mut is_valid := 0;
            if path_tok.token_type.tag == 4 { // TokenType::String = 4
                is_valid = 1;
            }
            if path_tok.token_type.tag == 2 { // TokenType::Ident = 2
                is_valid = 1;
            }
            
            if is_valid == 1 {
                paths.Push(std.Clone(ctx, path_tok.literal));
            }

            mut next_tok: token.Token[ctx];
            lexer.next_token(&l, &next_tok);
            if next_tok.token_type.tag == 37 { // TokenType::As = 37
                mut alias_tok: token.Token[ctx];
                lexer.next_token(&l, &alias_tok);
                
                // Move past the alias to the next token
                lexer.next_token(&l, &t);
            } else {
                // The token following the path is not "as", so it might be a semicolon or the next import
                t = next_tok;
            }
        }
    }
    return paths;
}

func get_dirname(path: str, ctx: &Arena) str {
    mut last_slash := 0 - 1;
    mut i := 0;
    while i < len(path) {
        mut b := std.str_byte_at(path, i);
        if b == 47 { // '/' = 47
            last_slash = i;
        }
        if b == 92 { // '\\' = 92
            last_slash = i;
        }
        i = i + 1;
    }
    if last_slash == 0 - 1 {
        return ".";
    }
    return std.str_slice(path, 0, last_slash);
}

func discover_source_files(dir_path: str, ctx: &Arena) std.Vector[str, ctx] {
    guard d := os.OpenDir(ctx, dir_path) else {
        mut empty_vec: std.Vector[str, ctx] := std.VectorNew(ctx);
        return empty_vec;
    }

    mut files: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut loop_active := 1;
    while loop_active == 1 {
        mut opt_entry := os.ReadDir(ctx, d);
        if opt_entry.Ok {
            mut name := opt_entry.Val.name;
            if len(name) > 4 {
                mut ext := std.str_slice(name, len(name) - 4, len(name));
                if std.str_eq(ext, ".gst") {
                    files.Push(os.path_join(dir_path, name, ctx));
                }
            }
        } else {
            loop_active = 0;
        }
    }
    os.CloseDir(d);
    return files;
}

func resolve_imports_recursive(entry_path: str, graph: *std.Graph[str, ctx], path_to_node: *std.HashMap[str, int, ctx], ctx: &Arena) {
    unsafe {
        mut lookup := (*path_to_node).get_opt(entry_path);
        match lookup {
            Some { val } => {
                return;
            }
            None => {
            }
        }

        // Add file as a node in the dependency graph
        mut node_idx := (*graph).AddNode(std.Clone(ctx, entry_path));
        (*path_to_node).Insert(std.Clone(ctx, entry_path), node_idx);

        // Load file contents from host file system
        mut content := os.ReadFile(ctx, entry_path);
        if len(content) == 0 {
            return;
        }

        // Parse relative paths from import headers
        mut imports := scan_imports(content, ctx);
        mut dir := get_dirname(entry_path, ctx);

        mut i := 0;
        while i < len(imports) {
            mut imp := imports[i];
            mut canonical_path := os.path_join(dir, imp, ctx);

            // Recurse to build transitively imported dependencies
            resolve_imports_recursive(canonical_path, graph, path_to_node, ctx);

            // Add directed edge representing dependency flow
            mut dep_lookup := (*path_to_node).get_opt(canonical_path);
            match dep_lookup {
                Some { val } => {
                    (*graph).AddEdge(node_idx, *val);
                }
                None => {
                    return;
                }
            }

            i = i + 1;
        }
    }
}

func dfs(node_idx: int, graph: *std.Graph[str, ctx], visiting: *std.HashMap[str, int, ctx], visited: *std.HashMap[str, int, ctx], order: *std.Vector[str, ctx], ctx: &Arena) {
    unsafe {
        mut name_ptr := (*graph).GetNode(node_idx);
        mut name := *name_ptr;
        
        mut lookup_visiting := (*visiting).get_opt(name);
        match lookup_visiting {
            Some { val } => {
                if *val == 1 {
                    os.LogStr("Cyclic dependency detected: ");
                    os.LogStr(name);
                    os.Exit(1);
                }
            }
            None => {
            }
        }
        
        mut lookup_visited := (*visited).get_opt(name);
        match lookup_visited {
            Some { val } => {
                if *val == 1 {
                    return;
                }
            }
            None => {
            }
        }
        
        (*visiting).Insert(name, 1);
        
        mut node_data := &(*graph).nodes.data[node_idx];
        mut i := 0;
        while i < len(node_data.edges) {
            mut dep_idx := node_data.edges[i];
            dfs(dep_idx, graph, visiting, visited, order, ctx);
            i = i + 1;
        }
        
        (*visiting).Remove(name);
        (*visited).Insert(name, 1);
        (*order).Push(name);
    }
}

func resolve_topological_sort(entry_path: str, graph: *std.Graph[str, ctx], path_to_node: *std.HashMap[str, int, ctx], ctx: &Arena) std.Vector[str, ctx] {
    mut visiting: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    mut visited: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    mut order: std.Vector[str, ctx] := std.VectorNew(ctx);
    
    unsafe {
        mut entry_lookup := (*path_to_node).get_opt(entry_path);
        match entry_lookup {
            Some { val } => {
                dfs(*val, graph, &visiting, &visited, &order, ctx);
            }
            None => {
                return order;
            }
        }
    }
    
    return order;
}
