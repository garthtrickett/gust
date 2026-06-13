
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut temp := "import 'std' as standard;|import 'os';|func main() {}";
            mut source := std.Concat("", temp);
            
            unsafe {
                mut bytes := source as []byte;
                mut i := 0;
                while i < len(bytes) {
                    if bytes[i] == 39 {
                        bytes[i] = 34;
                    }
                    if bytes[i] == 124 {
                        bytes[i] = 10;
                    }
                    i = i + 1;
                }
            }
            
            mut paths := resolver.scan_imports(source, ctx);
            os.LogInt(len(paths));
            os.LogStr(paths[0]);
            os.LogStr(paths[1]);
        }
    