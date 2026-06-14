import "ast.gst" as ast;

type StructLayout[ctx] struct {
    brand: Index[str, ctx],
    fields: std.HashMap[str, ast.Type[ctx], ctx]
}

type FunctionSignature[ctx] struct {
    param_names: std.Vector[str, ctx],
    params: std.Vector[ast.Type[ctx], ctx],
    return_type: ast.Type[ctx]
}