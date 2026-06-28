import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut payload_resource_shape := typechecker.make_type_struct("main__ResourceShapePayload", "", ctx);
    mut resource_shape := typechecker.make_type_resource(payload_resource_shape, ctx);

    if typechecker.type_is_resource(resource_shape, ctx) != 1 {
        os.LogStr("Error: Resource payload wrapper was not recognized as Resource type shape");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_matches(resource_shape, payload_resource_shape, ctx) != 1 {
        os.LogStr("Error: Resource payload type did not round-trip through Resource type shape");
        os.Exit(1);
    }
    if len(typechecker.resource_type_payload_name(resource_shape, ctx)) == 0 {
        os.LogStr("Error: Resource payload type name must be available for diagnostics metadata");
        os.Exit(1);
    }

    mut recovered_payload_resource_shape := typechecker.resource_type_payload(resource_shape, ctx);
    if typechecker.types_match(recovered_payload_resource_shape, payload_resource_shape, ctx) != 1 {
        os.LogStr("Error: recovered Resource payload does not match original payload type");
        os.Exit(1);
    }

    if typechecker.type_is_resource(payload_resource_shape, ctx) != 0 {
        os.LogStr("Error: plain struct payload must not be recognized as Resource type shape");
        os.Exit(1);
    }
    if typechecker.resource_type_payload(payload_resource_shape, ctx).tag != 3 { // Void
        os.LogStr("Error: non-Resource payload lookup must return Void sentinel");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_matches(payload_resource_shape, payload_resource_shape, ctx) != 0 {
        os.LogStr("Error: non-Resource type must not match Resource payload helper");
        os.Exit(1);
    }
    if len(typechecker.resource_type_payload_name(payload_resource_shape, ctx)) != 0 {
        os.LogStr("Error: non-Resource payload name must default to empty string");
        os.Exit(1);
    }

    mut empty_args_resource_shape: std.Vector[typechecker.ast.Type[ctx], ctx] := std.VectorNew(ctx);
    mut malformed_empty_resource_shape := typechecker.make_type_generic("Resource", empty_args_resource_shape, ctx);
    if typechecker.type_is_resource(malformed_empty_resource_shape, ctx) != 0 {
        os.LogStr("Error: Resource generic with no payload must not be accepted");
        os.Exit(1);
    }

    mut extra_payload_resource_shape := typechecker.make_type_int();
    mut two_args_resource_shape: std.Vector[typechecker.ast.Type[ctx], ctx] := std.VectorNew(ctx);
    two_args_resource_shape.Push(payload_resource_shape);
    two_args_resource_shape.Push(extra_payload_resource_shape);
    mut malformed_two_arg_resource_shape := typechecker.make_type_generic("Resource", two_args_resource_shape, ctx);
    if typechecker.type_is_resource(malformed_two_arg_resource_shape, ctx) != 0 {
        os.LogStr("Error: Resource generic with more than one payload must not be accepted");
        os.Exit(1);
    }

    mut vector_args_resource_shape: std.Vector[typechecker.ast.Type[ctx], ctx] := std.VectorNew(ctx);
    vector_args_resource_shape.Push(payload_resource_shape);
    mut non_resource_generic_shape := typechecker.make_type_generic("Vector", vector_args_resource_shape, ctx);
    if typechecker.type_is_resource(non_resource_generic_shape, ctx) != 0 {
        os.LogStr("Error: non-Resource generic must not be recognized as Resource type shape");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert Resource type-shape helpers verified!");
}