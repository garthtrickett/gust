
        import "token.gst" as token;
        import "ast.gst" as ast;
        import "errors.gst" as errs;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut p: ast.Program[ctx];
            p.statements = os.ArenaAlloc(ctx);
            
            mut s: ast.Statement[ctx];
            s.tag = 13;
            s.Expression.expr = os.ArenaAlloc(ctx);
            s.Expression.span.start.line = 1;
            s.Expression.span.start.column = 5;
            
            mut e: ast.Expression[ctx];
            e.tag = 1;
            e.Integer.val = 100;
            
            mut error_ptr: Index[errs.CompilerError, ctx] := os.ArenaAlloc(ctx);
            ctx[error_ptr].kind.tag = 2;
            ctx[error_ptr].message = "Type mismatch!";
            ctx[error_ptr].span = s.Expression.span;
            
            mut res: errs.Result[ast.Expression[ctx], ctx];
            res.tag = 1;
            res.Err.error = error_ptr;
            
            os.LogInt(ctx[res.Err.error].kind.tag);
            os.LogStr(ctx[res.Err.error].message);
        }
    