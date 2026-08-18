// Phase 18.1 native smoke: compiler-owned target authority.
//
// Two things are proven here. A target identity must agree with the Phase 14
// target layout authority on pointer width and endianness, and an explicitly
// requested target must never consult the host. Both are rejections, not
// warnings, so the smoke exercises the accepting case and each refusal.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func linux_x86_64_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func declare(
    table: target.MirTargetAuthorityTable[ctx],
    target_id: str,
    triple: str,
    architecture: str,
    vendor: str,
    operating_system: str,
    environment: str,
    pointer_width_bits: int,
    endianness: str,
    ctx: &Arena
) target.MirTargetAuthorityTable[ctx] {
    mut declared: target.MirDeclaredTriple[ctx];
    declared.target_id = std.Clone(ctx, target_id);
    declared.target_triple = std.Clone(ctx, triple);
    declared.architecture = std.Clone(ctx, architecture);
    declared.vendor = std.Clone(ctx, vendor);
    declared.operating_system = std.Clone(ctx, operating_system);
    declared.environment = std.Clone(ctx, environment);
    declared.pointer_width_bits = pointer_width_bits;
    declared.endianness = std.Clone(ctx, endianness);
    declared.declared_source = std.Clone(ctx, "phase17_runtime_package_authority_target_packages");
    return target.mir_target_table_with_declared_triple(table, declared, ctx);
}

func select_target(
    table: target.MirTargetAuthorityTable[ctx],
    selection_id: str,
    target_id: str,
    mode: str,
    requested: str,
    consulted_host: int,
    ctx: &Arena
) target.MirTargetAuthorityTable[ctx] {
    mut selection: target.MirTargetSelection[ctx];
    selection.selection_id = std.Clone(ctx, selection_id);
    selection.target_id = std.Clone(ctx, target_id);
    selection.selection_mode = std.Clone(ctx, mode);
    selection.requested_triple = std.Clone(ctx, requested);
    selection.consulted_host = consulted_host;
    selection.rejection_reason = std.Clone(ctx, "");
    return target.mir_target_table_with_selection(table, selection, ctx);
}

func identify(
    table: target.MirTargetAuthorityTable[ctx],
    target_id: str,
    triple: str,
    pointer_width_bits: int,
    endianness: str,
    agreement: str,
    selection_id: str,
    ctx: &Arena
) target.MirTargetAuthorityTable[ctx] {
    mut identity: target.MirTargetIdentity[ctx];
    identity.target_id = std.Clone(ctx, target_id);
    identity.target_triple = std.Clone(ctx, triple);
    identity.architecture = std.Clone(ctx, "x86_64");
    identity.vendor = std.Clone(ctx, "unknown");
    identity.operating_system = std.Clone(ctx, "linux");
    identity.environment = std.Clone(ctx, "gnu");
    identity.pointer_width_bits = pointer_width_bits;
    identity.endianness = std.Clone(ctx, endianness);
    identity.layout_authority_id = std.Clone(ctx, "phase14_compiler_owned_layout_authority_v1");
    identity.layout_agreement = std.Clone(ctx, agreement);
    identity.selection_id = std.Clone(ctx, selection_id);
    return target.mir_target_table_with_identity(table, identity, ctx);
}

func base_table(ctx: &Arena) target.MirTargetAuthorityTable[ctx] {
    mut table := target.mir_target_make_empty_table(ctx);
    table = declare(table, linux_x86_64_id(), "x86_64-unknown-linux-gnu", "x86_64", "unknown", "linux", "gnu", 64, "little", ctx);
    return table;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut table := base_table(&ctx);
    table = select_target(table, "selection:explicit:1", linux_x86_64_id(), "explicit_requested_target", "x86_64-unknown-linux-gnu", 0, &ctx);
    table = identify(table, linux_x86_64_id(), "x86_64-unknown-linux-gnu", 64, "little", "agrees_with_phase14_target_layout_authority", "selection:explicit:1", &ctx);

    mut validation := target.mir_target_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    if target.mir_target_triple_is_declared(table, "x86_64-unknown-linux-gnu", &ctx) == 0 { os.Exit(2); }
    if target.mir_target_triple_is_declared(table, "riscv64-unknown-linux-gnu", &ctx) == 1 { os.Exit(3); }
    if target.mir_target_declared_pointer_width(table, linux_x86_64_id(), &ctx) != 64 { os.Exit(4); }
    if target.mir_target_identity_agrees_with_layout(table, linux_x86_64_id(), &ctx) == 0 { os.Exit(5); }
    if target.mir_target_selection_consulted_host(table, "selection:explicit:1", &ctx) == 1 { os.Exit(6); }

    mut request := target_request.mir_serialize_target_request(table, &ctx);
    mut witness := target_request.mir_target_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase18-target.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-target.mir-to-c.witness", witness) == 0 { os.Exit(7); }

    // Rejection: an explicitly requested target that consulted the host.
    mut probed := base_table(&ctx);
    probed = select_target(probed, "selection:explicit:2", linux_x86_64_id(), "explicit_requested_target", "x86_64-unknown-linux-gnu", 1, &ctx);
    mut probed_validation := target.mir_target_authority_table_validate(probed, &ctx);
    if probed_validation.valid == 1 || std.str_eq(probed_validation.reason_code, "host_inference_under_explicit_target") == 0 { os.Exit(8); }

    // Rejection: a triple outside the declared vocabulary.
    mut unknown := base_table(&ctx);
    unknown = select_target(unknown, "selection:explicit:3", linux_x86_64_id(), "explicit_requested_target", "riscv64-unknown-linux-gnu", 0, &ctx);
    mut unknown_validation := target.mir_target_authority_table_validate(unknown, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "unknown_target_triple") == 0 { os.Exit(9); }

    // Rejection: an identity whose pointer width disagrees with the layout owner.
    mut mismatched := base_table(&ctx);
    mismatched = select_target(mismatched, "selection:explicit:4", linux_x86_64_id(), "explicit_requested_target", "x86_64-unknown-linux-gnu", 0, &ctx);
    mismatched = identify(mismatched, linux_x86_64_id(), "x86_64-unknown-linux-gnu", 32, "little", "agrees_with_phase14_target_layout_authority", "selection:explicit:4", &ctx);
    mut mismatched_validation := target.mir_target_authority_table_validate(mismatched, &ctx);
    if mismatched_validation.valid == 1 || std.str_eq(mismatched_validation.reason_code, "target_layout_disagreement") == 0 { os.Exit(10); }

    // Rejection: an identity that does not claim layout agreement at all.
    mut unclaimed := base_table(&ctx);
    unclaimed = select_target(unclaimed, "selection:explicit:5", linux_x86_64_id(), "explicit_requested_target", "x86_64-unknown-linux-gnu", 0, &ctx);
    unclaimed = identify(unclaimed, linux_x86_64_id(), "x86_64-unknown-linux-gnu", 64, "little", "unverified", "selection:explicit:5", &ctx);
    mut unclaimed_validation := target.mir_target_authority_table_validate(unclaimed, &ctx);
    if unclaimed_validation.valid == 1 || std.str_eq(unclaimed_validation.reason_code, "target_layout_disagreement") == 0 { os.Exit(11); }

    // Rejection: a duplicate declared triple.
    mut duplicated := base_table(&ctx);
    duplicated = declare(duplicated, linux_x86_64_id(), "x86_64-unknown-linux-gnu", "x86_64", "unknown", "linux", "gnu", 64, "little", &ctx);
    mut duplicated_validation := target.mir_target_authority_table_validate(duplicated, &ctx);
    if duplicated_validation.valid == 1 || std.str_eq(duplicated_validation.reason_code, "duplicate_declared_triple") == 0 { os.Exit(12); }

    os.LogStr("SUCCESS: Phase 18.1 target authority smoke passed");
}
