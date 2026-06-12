
        import "token.gst" as token;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut p: ast.Program[ctx];
            p.statements = os.ArenaAlloc(ctx);
            
            mut s: ast.Statement[ctx];
            s.tag = 13;
            s.Expression.expr = os.ArenaAlloc(ctx);
            
            mut e: ast.Expression[ctx];
            e.tag = 1;
            e.Integer.val = 42;
        }
    