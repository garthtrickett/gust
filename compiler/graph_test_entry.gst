
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive("/tmp/nix-shell.LeOxSh/gust_graph_test/main.gst", &graph, &path_to_node, ctx);
            
            guard main_idx := path_to_node.Get("/tmp/nix-shell.LeOxSh/gust_graph_test/main.gst") else {
                return;
            }
            guard lib_idx := path_to_node.Get("/tmp/nix-shell.LeOxSh/gust_graph_test/lib.gst") else {                return;
            }
            guard deep_idx := path_to_node.Get("/tmp/nix-shell.LeOxSh/gust_graph_test/nested/deep.gst") else {
                return;
            }
            
            os.LogStr("main ok");
            os.LogStr("lib ok");
            os.LogStr("deep ok");
            
            os.LogInt(graph.nodes.len);
            
            unsafe {
                mut main_node := &graph.nodes.data[main_idx];
                os.LogInt(len(main_node.edges));
                
                mut target_idx := main_node.edges[0];
                mut name_ptr := graph.GetNode(target_idx);
                os.LogStr(*name_ptr);
            }
        }
        