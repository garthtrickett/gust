// Internal metadata checks only; synthetic identity strings never select
// runtime allocators, resource slots or public lifetime relationships.
import "../typechecker.gst" as checker;
import "../ast.gst" as ast;
func main() int {
    mut ctx := os.Arena.New();
    unsafe {
        mut env := checker.env_new(&ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        env.current_allocator_scope = scope;
        ctx[scope].primitive_arena_observations.Insert("holder.arena", checker.allocator_identity_proof("A", 0, &ctx));
        mut before := checker.env_snapshot_allocator_observations(&env, &ctx);
        ctx[scope].primitive_arena_observations.Insert("holder.arena", checker.allocator_identity_proof("B", 0, &ctx));
        mut after := checker.env_snapshot_allocator_observations(&env, &ctx);
        mut joined := checker.typechecker_join_allocator_observations(before, after, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard ambiguous := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 1; }
        if len(ambiguous.identity) != 0 || ambiguous.unresolved != 1 { return 2; }
        os.LogInt(1);

        checker.env_restore_allocator_observations(before, &ctx);
        guard original := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 3; }
        if std.str_eq(original.identity, "A") == 0 || original.unresolved != 0 { return 4; }
        os.LogInt(1);

        mut same := checker.typechecker_join_allocator_observations(before, before, &ctx);
        checker.env_restore_allocator_observations(same, &ctx);
        guard preserved := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 5; }
        if std.str_eq(preserved.identity, "A") == 0 || preserved.unresolved != 0 { return 6; }
        os.LogInt(1);

        ctx[scope].primitive_arena_observations.Insert("extra.arena", checker.allocator_identity_proof("B", 0, &ctx));
        mut extra := checker.env_snapshot_allocator_observations(&env, &ctx);
        joined = checker.typechecker_join_allocator_observations(before, extra, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard one_sided := ctx[scope].primitive_arena_observations.Get("extra.arena") else { return 7; }
        if len(one_sided.identity) != 0 || one_sided.unresolved != 1 { return 8; }

        // A synthetic nonempty unknown is not a proved physical receiver.
        checker.env_restore_allocator_observations(before, &ctx);
        ctx[scope].primitive_arena_observations.Insert("holder.arena", checker.allocator_identity_proof("A", 1, &ctx));
        mut unknown := checker.env_snapshot_allocator_observations(&env, &ctx);
        joined = checker.typechecker_join_allocator_observations(unknown, unknown, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard retained_unknown := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 9; }
        if std.str_eq(retained_unknown.identity, "A") == 0 || retained_unknown.unresolved != 1 { return 10; }
        joined = checker.typechecker_join_allocator_observations(before, unknown, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard conflicting := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 11; }
        if len(conflicting.identity) != 0 || conflicting.unresolved != 1 { return 12; }

        checker.env_restore_allocator_observations(before, &ctx);
        ctx[scope].primitive_arena_exposed_storage.Insert("holder", 1);
        mut exposed := checker.env_snapshot_allocator_observations(&env, &ctx);
        checker.env_restore_allocator_observations(before, &ctx);
        if ctx[scope].primitive_arena_exposed_storage.Get("holder").Ok { return 13; }
        joined = checker.typechecker_join_allocator_observations(before, exposed, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        if ctx[scope].primitive_arena_exposed_storage.Get("holder").Ok == false { return 14; }
        checker.scope_insert(scope, "holder", checker.make_type_int(), &ctx);
        ctx[scope].primitive_arena_observations.Remove("holder.arena");
        ctx[scope].allocator_bindings.Insert("holder.arena", checker.allocator_identity_proof("A", 0, &ctx));
        mut root: ast.Expression[ctx];
        root.tag = 0;
        root.Identifier.name = "holder";
        mut root_index: Index[ast.Expression[ctx],ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(root_index, root);
        mut field: ast.Expression[ctx];
        field.tag = 11;
        field.Selector.left = root_index;
        field.Selector.right = "arena";
        mut field_index: Index[ast.Expression[ctx],ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(field_index, field);
        mut fallback := checker.env_arena_lifecycle_expression_proof(field_index, &env, &ctx);
        if std.str_eq(fallback.identity, "A") == 0 || fallback.unresolved != 1 { return 15; }

        checker.env_restore_allocator_observations(before, &ctx);
        mut changed := ctx[scope];
        changed.primitive_arena_indirect_write = 1;
        ctx.Set(scope, changed);
        mut indirect := checker.env_snapshot_allocator_observations(&env, &ctx);
        checker.env_restore_allocator_observations(before, &ctx);
        if ctx[scope].primitive_arena_indirect_write != 0 { return 16; }
        joined = checker.typechecker_join_allocator_observations(before, indirect, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        if ctx[scope].primitive_arena_indirect_write != 1 { return 17; }
        fallback = checker.env_arena_lifecycle_expression_proof(field_index, &env, &ctx);
        if fallback.unresolved != 1 { return 18; }
        mut copied_fields := checker.env_arena_lifecycle_capture_field_observations(&env, root_index, checker.make_type_struct("Holder", "", &ctx), &ctx);
        guard copied_unknown := copied_fields.Get(".arena") else { return 19; }
        if copied_unknown.unresolved != 1 { return 20; }
        checker.env_restore_allocator_observations(before, &ctx);
        mut computed: ast.Expression[ctx];
        computed.tag = 12; // An unrepresented computed storage path, not a call.
        mut computed_index: Index[ast.Expression[ctx],ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(computed_index, computed);
        checker.env_arena_lifecycle_observe_indirect_write(&env, computed_index, &ctx);
        if ctx[scope].primitive_arena_indirect_write != 1 { return 21; }
        os.LogInt(1);
    }
    ctx.Free();
    return 0;
}
