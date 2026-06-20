
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive("/tmp/nix-shell.9RpVob/gust_sort_test/main.gst", &graph, &path_to_node, ctx);
            
            mut order := resolver.resolve_topological_sort("/tmp/nix-shell.9RpVob/gust_sort_test/main.gst", &graph, &path_to_node, ctx);
            
            os.LogInt(len(order));
            mut i := 0;
            while i < len(order) {
                os.LogStr(order[i]);
                i = i + 1;
            }
        }
        