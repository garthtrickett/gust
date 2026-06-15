
        import "token.gst" as token;
        import "ast.gst" as ast;
        import "typechecker.gst" as typechecker;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);

            mut env := typechecker.env_new(ctx);

            // Trigger argument mismatch: std.Vector expects 2 arguments but we provide 1
            mut vec_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
            vec_args.Push(typechecker.make_type_int());

            mut res := typechecker.monomorphize(&env, "std.Vector", vec_args, ctx);
            if res.tag == 1 { // Err
                os.LogStr("Argument mismatch correctly detected!");
                unsafe {
                    os.LogStr(ctx[res.Err.error].message);
                }
            } else { 
                os.LogStr("Failed to detect argument mismatch!");
            }
        }
    
