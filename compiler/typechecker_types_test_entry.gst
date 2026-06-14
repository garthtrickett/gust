import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut layout: typechecker.StructLayout[ctx];
    layout.brand = empty[Index[str, ctx]];
    layout.fields = std.HashMapNew(ctx);

    mut sig: typechecker.FunctionSignature[ctx];
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.return_type.tag = 3; // Void

    os.LogInt(sig.return_type.tag);
}