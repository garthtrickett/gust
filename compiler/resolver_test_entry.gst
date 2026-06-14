
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut source := "import 'std' as standard; import 'os'; func main() {}";
            
            mut paths := resolver.scan_imports(source, ctx);
            os.LogInt(len(paths));
            os.LogStr(paths[0]);
            os.LogStr(paths[1]);
        }
    