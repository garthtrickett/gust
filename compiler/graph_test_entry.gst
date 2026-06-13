
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive("/tmp/nix-shell.1rMrUE/gust_graph_test/main.gst", &graph, &path_to_node, ctx);
            
            mut lookup_main := path_to_node.Get("/tmp/nix-shell.1rMrUE/gust_graph_test/main.gst");
            mut lookup_lib := path_to_node.Get("/tmp/nix-shell.1rMrUE/gust_graph_test/lib.gst");
            mut lookup_deep := path_to_node.Get("/tmp/nix-shell.1rMrUE/gust_graph_test/nested/deep.gst");
            
            if lookup_main.Ok {
                os.LogStr("main ok");
            }
            if lookup_lib.Ok {
                os.LogStr("lib ok");
            }
            if lookup_deep.Ok {
                os.LogStr("deep ok");
            }
            
            os.LogInt(graph.nodes.len);
            
            unsafe {
                mut main_node := &graph.nodes.data[lookup_main.Val];
                os.LogInt(len(main_node.edges));
                
                mut target_idx := main_node.edges[0];
                mut name_ptr := graph.GetNode(target_idx);
                os.LogStr(*name_ptr);
            }
        }
        