// Internal metadata checks only; synthetic identity strings never select
// runtime allocators, resource slots or public lifetime relationships.
import "../typechecker.gst" as checker;
func main() int {
    mut ctx := os.Arena.New();
    unsafe {
        mut env := checker.env_new(&ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], &ctx);
        env.current_allocator_scope = scope;
        ctx[scope].primitive_arena_observations.Insert("holder.arena", "A");
        mut before := checker.env_snapshot_allocator_observations(&env, &ctx);
        ctx[scope].primitive_arena_observations.Insert("holder.arena", "B");
        mut after := checker.env_snapshot_allocator_observations(&env, &ctx);
        mut joined := checker.typechecker_join_allocator_observations(before, after, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard ambiguous := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 1; }
        if len(ambiguous) != 0 { return 2; }
        os.LogInt(1);

        checker.env_restore_allocator_observations(before, &ctx);
        guard original := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 3; }
        if std.str_eq(original, "A") == 0 { return 4; }
        os.LogInt(1);

        mut same := checker.typechecker_join_allocator_observations(before, before, &ctx);
        checker.env_restore_allocator_observations(same, &ctx);
        guard preserved := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 5; }
        if std.str_eq(preserved, "A") == 0 { return 6; }
        os.LogInt(1);

        ctx[scope].primitive_arena_observations.Insert("extra.arena", "B");
        mut extra := checker.env_snapshot_allocator_observations(&env, &ctx);
        joined = checker.typechecker_join_allocator_observations(before, extra, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard one_sided := ctx[scope].primitive_arena_observations.Get("extra.arena") else { return 7; }
        if len(one_sided) != 0 { return 8; }
        os.LogInt(1);
    }
    ctx.Free();
    return 0;
}
