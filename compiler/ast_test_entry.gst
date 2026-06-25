import "token.gst" as token;
import "ast.gst" as ast;
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut p: ast.Program[ctx];
    mut s: ast.Statement[ctx];
    mut e: ast.Expression[ctx];
    unsafe {
        p.statements = os.ArenaAlloc(ctx);

        s.tag = 13;
        s.Expression.expr = os.ArenaAlloc(ctx);

        e.tag = 1;
        e.Integer.val = 42;
    }
}
