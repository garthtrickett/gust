// Internal metadata checks only; synthetic identity strings never select
// runtime allocators, resource slots or public lifetime relationships.
import "../typechecker.gst" as checker;
import "../ast.gst" as ast;
import "../lexer.gst" as lexer;
import "../parser.gst" as parser;
func check_literal_observation_source(source: str, expected: str, ctx: &Arena) int {
    unsafe {
        mut lex: lexer.Lexer[ctx];
        lexer.init_lexer(&lex, source);
        mut parse: parser.Parser[ctx];
        parser.init_parser(&parse, &lex, ctx);
        mut program := parser.parse_program(&parse, ctx);
        if len(parse.errors) != 0 { return 0; }
        mut env := checker.env_new(ctx);
        mut scope := checker.scope_new(empty[Index[checker.Scope[ctx], ctx]], ctx);
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
        mut i := 0;
        while i < len(statements) { checker.env_pre_register_template_statement(&env, statements[i], ctx); i = i + 1; }
        i = 0;
        while i < len(statements) { checker.env_pre_register_statement(&env, statements[i], ctx); i = i + 1; }
        i = 0;
        while i < len(statements) {
            mut statement: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx.Set(statement, statements[i]);
            checker.check_statement(statement, &env, scope, ctx);
            i = i + 1;
        }
        if len(expected) == 0 {
            if len(env.errors) == 0 { return 1; }
            return 0;
        }
        if len(env.errors) != 1 { return 0; }
        if std.str_find(env.errors[0].message, expected) >= 0 { return 1; }
        return 0;
    }
}
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

        // Literal branch selection keeps the complete conservative taint join.
        mut condition: ast.Expression[ctx];
        condition.tag = 3;
        condition.Bool.val = 1;
        mut condition_index: Index[ast.Expression[ctx],ctx] := os.ArenaAlloc(&ctx);
        ctx.Set(condition_index, condition);
        joined = checker.typechecker_if_allocator_observations(condition_index, after, before, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard literal_true := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 22; }
        if std.str_eq(literal_true.identity, "B") == 0 { return 23; }
        condition.Bool.val = 0; ctx.Set(condition_index, condition);
        joined = checker.typechecker_if_allocator_observations(condition_index, after, before, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard literal_false := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 24; }
        if std.str_eq(literal_false.identity, "A") == 0 { return 25; }
        condition.tag = 0; condition.Identifier.name = "flag"; ctx.Set(condition_index, condition);
        joined = checker.typechecker_if_allocator_observations(condition_index, after, before, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard dynamic := ctx[scope].primitive_arena_observations.Get("holder.arena") else { return 26; }
        if len(dynamic.identity) != 0 || dynamic.unresolved != 1 { return 27; }
        condition.tag = 3; condition.Bool.val = 1; ctx.Set(condition_index, condition);
        joined = checker.typechecker_if_allocator_observations(condition_index, before, exposed, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        fallback = checker.env_arena_lifecycle_expression_proof(field_index, &env, &ctx);
        if fallback.unresolved != 1 { return 28; }
        joined = checker.typechecker_if_allocator_observations(condition_index, before, indirect, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        fallback = checker.env_arena_lifecycle_expression_proof(field_index, &env, &ctx);
        if fallback.unresolved != 1 { return 29; }
        joined = checker.typechecker_if_allocator_observations(condition_index, before, extra, &ctx);
        checker.env_restore_allocator_observations(joined, &ctx);
        guard still_missing := ctx[scope].primitive_arena_observations.Get("extra.arena") else { return 30; }
        if len(still_missing.identity) != 0 || still_missing.unresolved != 1 { return 31; }

        // Execute the current compiler's parser/typechecker only. These source
        // controls never invoke a backend or execute any represented user code.
        // original_inner_writes_outer_holder
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { holder.arena = second; } holder.arena.Free(); mut value := std.Clone(first,\"live\"); }", "", &ctx) == 0 { return 60; }
        // literal_false_without_else
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if false { holder.arena = second; } holder.arena.Free(); mut value := std.Clone(second,\"live\"); }", "", &ctx) == 0 { return 61; }
        // literal_false_with_else
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if false { holder.arena = first; } else { holder.arena = second; } holder.arena.Free(); mut value := std.Clone(first,\"live\"); }", "", &ctx) == 0 { return 62; }
        // literal_true_with_else
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { holder.arena = second; } else { holder.arena = first; } holder.arena.Free(); mut value := std.Clone(first,\"live\"); }", "", &ctx) == 0 { return 63; }
        // unknown_bool_parameter
        if check_literal_observation_source("type Holder struct { arena: Arena } func probe(flag: bool) { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if flag { holder.arena = second; } defer holder.arena.Free(); } func main() { probe(true); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 64; }
        // named_bool_is_not_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; mut flag := true; if flag { holder.arena = second; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 65; }
        // comparison_is_not_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if 1 == 1 { holder.arena = second; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 66; }
        // uninitialized_unselected_arm
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut holder: Holder; if false { holder.arena = first; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 67; }
        // initialized_selected_arm
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut holder: Holder; if true { holder.arena = first; } holder.arena.Free(); }", "", &ctx) == 0 { return 68; }
        // nested_holder_shadow
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { mut holder: Holder; holder.arena = second; } holder.arena.Free(); mut value := std.Clone(second,\"live\"); }", "", &ctx) == 0 { return 69; }
        // exposure_before_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; mut alias := &holder; if true { holder.arena = second; } defer holder.arena.Free(); }", "[ResourceDeferredUnresolved]", &ctx) == 0 { return 70; }
        // exposure_in_selected_arm
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { mut alias := &holder; } else { holder.arena = second; } defer holder.arena.Free(); }", "[ResourceDeferredUnresolved]", &ctx) == 0 { return 71; }
        // exposure_in_unselected_arm
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { holder.arena = second; } else { mut alias := &holder; } defer holder.arena.Free(); }", "[ResourceDeferredUnresolved]", &ctx) == 0 { return 72; }
        // indirect_write_before_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; mut alias := &holder; unsafe { (*alias).arena = second; } if true { holder.arena = first; } defer holder.arena.Free(); }", "[ResourceDeferredUnresolved]", &ctx) == 0 { return 73; }
        // selected_arm_terminates
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if true { holder.arena = second; return; } else { holder.arena = first; } defer holder.arena.Free(); }", "", &ctx) == 0 { return 74; }
        // call_is_not_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func yes() bool { return true; } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if yes() { holder.arena = second; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 75; }
        // cast_is_not_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if (true as bool) { holder.arena = second; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 76; }
        // integer_is_not_bool_literal
        if check_literal_observation_source("type Holder struct { arena: Arena } func main() { mut first := os.Arena.New(); mut second := os.Arena.New(); mut holder: Holder; holder.arena = first; if 1 { holder.arena = second; } defer holder.arena.Free(); }", "[BrandIdentityMismatch]", &ctx) == 0 { return 77; }
        os.LogInt(1);
    }
    ctx.Free();
    return 0;
}
