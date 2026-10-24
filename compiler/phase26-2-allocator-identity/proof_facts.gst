// Internal proof metadata, not a new public mixed-origin source construction.
import "../typechecker.gst" as checker;
func main() int {
    mut ctx := os.Arena.New();
    unsafe {
        mut env := checker.env_new(&ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        env.current_allocator_scope = scope;
        mut root_type := checker.make_type_struct("Root", "brand", &ctx);
        mut field_type := checker.make_type_struct("Field", "brand", &ctx);
        mut root_layout: checker.StructLayout[ctx];
        root_layout.brand = root_type.Struct.brand;
        root_layout.fields = std.HashMapNew(&ctx);
        root_layout.fields.Insert("owner", field_type);
        mut field_layout: checker.StructLayout[ctx];
        field_layout.brand = field_type.Struct.brand;
        field_layout.fields = std.HashMapNew(&ctx);
        env.struct_registry.Insert("Root", root_layout);
        env.struct_registry.Insert("Field", field_layout);
        ctx[scope].bindings.Insert("source", root_type);
        ctx[scope].bindings.Insert("absent", root_type);
        ctx[scope].allocator_bindings.Insert("source.owner",
            checker.allocator_identity_proof("explicit-field-unknown", 1, &ctx));
        mut root := checker.allocator_identity_proof("known-root", 0, &ctx);
        mut visited: std.HashMap[str, int, ctx] := std.HashMapNew(&ctx);
        mut copied := checker.env_capture_resource_field_allocator_constraints(
            &env, scope, "copy", "source", root_type, "brand", root, root,
            1, visited, &ctx);
        guard present := ctx[scope].allocator_bindings.Get("copy.owner") else { return 1; }
        if present.unresolved != 1 { return 2; }
        if std.str_eq(present.identity, "explicit-field-unknown") == 0 { return 3; }
        os.LogInt(1);
        mut fallback := checker.env_capture_resource_field_allocator_constraints(
            &env, scope, "fallback", "absent", root_type, "brand", root, root,
            1, visited, &ctx);
        guard missing := ctx[scope].allocator_bindings.Get("fallback.owner") else { return 4; }
        if missing.unresolved != 0 { return 5; }
        if std.str_eq(missing.identity, "known-root") == 0 { return 6; }
        os.LogInt(1);
    }
    return 0;
}
