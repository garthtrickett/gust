
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive("/tmp/nix-shell.uGH5Bs/gust_cycle_test/main.gst", &graph, &path_to_node, ctx);
            
            resolver.resolve_topological_sort("/tmp/nix-shell.uGH5Bs/gust_cycle_test/main.gst", &graph, &path_to_node, ctx);
        }
        