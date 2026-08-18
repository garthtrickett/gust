// Phase 18.1 compiler-owned target authority.
//
// This module is the sole semantic owner for target identity: the declared
// triple vocabulary, the architecture, vendor, operating system, environment,
// pointer width, and endianness of a selected target, and the record of how
// that target was selected. Canonical MIR, MIR-to-C, Cranelift, runtime
// package selection, link planning, diagnostics, and the Phase 9G artifact
// planner consume these records.
//
// A target is never inferred from the host that happens to be running the
// compiler. When an explicit target is requested, the host is not consulted at
// all; when none is requested, a declared default is selected and recorded as
// such. Backends do not derive a target from a native ISA builder, a build
// host preprocessor macro, a file extension, or an output probe.
//
// Target identity does not restate layout. Pointer width and endianness are
// owned by the Phase 14 target layout authority, and this module requires
// agreement with it rather than recomputing either value.

type MirDeclaredTriple[ctx] struct {
    target_id: str,
    target_triple: str,
    architecture: str,
    vendor: str,
    operating_system: str,
    environment: str,
    pointer_width_bits: int,
    endianness: str,
    declared_source: str
}

type MirTargetSelection[ctx] struct {
    selection_id: str,
    target_id: str,
    selection_mode: str,
    requested_triple: str,
    consulted_host: int,
    rejection_reason: str
}

type MirTargetIdentity[ctx] struct {
    target_id: str,
    target_triple: str,
    architecture: str,
    vendor: str,
    operating_system: str,
    environment: str,
    pointer_width_bits: int,
    endianness: str,
    layout_authority_id: str,
    layout_agreement: str,
    selection_id: str
}

type MirTargetAuthorityTable[ctx] struct {
    format: str,
    semantic_authority: str,
    identity_policy: str,
    selection_policy: str,
    layout_agreement_policy: str,
    declared_triples: Index[std.Vector[MirDeclaredTriple[ctx], ctx], ctx],
    selections: Index[std.Vector[MirTargetSelection[ctx], ctx], ctx],
    identities: Index[std.Vector[MirTargetIdentity[ctx], ctx], ctx]
}

func mir_target_empty_triples(ctx: &Arena) Index[std.Vector[MirDeclaredTriple[ctx], ctx], ctx] { mut values: std.Vector[MirDeclaredTriple[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirDeclaredTriple[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }

func mir_target_empty_selections(ctx: &Arena) Index[std.Vector[MirTargetSelection[ctx], ctx], ctx] { mut values: std.Vector[MirTargetSelection[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirTargetSelection[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }

func mir_target_empty_identities(ctx: &Arena) Index[std.Vector[MirTargetIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirTargetIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirTargetIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }

func mir_target_make_empty_table(ctx: &Arena) MirTargetAuthorityTable[ctx] {
    mut table: MirTargetAuthorityTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_target_authority_table.v1");
    table.semantic_authority = std.Clone(ctx, "compiler/mir_target_authority.gst");
    table.identity_policy = std.Clone(ctx, "compiler_declared_triple_vocabulary_no_host_inference");
    table.selection_policy = std.Clone(ctx, "explicit_requested_target_or_declared_default_never_host_probe");
    table.layout_agreement_policy = std.Clone(ctx, "pointer_width_and_endianness_must_agree_with_phase14_target_layout_authority");
    table.declared_triples = mir_target_empty_triples(ctx);
    table.selections = mir_target_empty_selections(ctx);
    table.identities = mir_target_empty_identities(ctx);
    return table;
}

// A triple is declared only when it appears in the registry-owned vocabulary.
// Anything else is unknown, and unknown is a rejection rather than a guess.
func mir_target_triple_is_declared(table: MirTargetAuthorityTable[ctx], target_triple: str, ctx: &Arena) int {
    mut values: std.Vector[MirDeclaredTriple[ctx], ctx] := ctx[table.declared_triples];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].target_triple, target_triple) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_target_declared_pointer_width(table: MirTargetAuthorityTable[ctx], target_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirDeclaredTriple[ctx], ctx] := ctx[table.declared_triples];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].target_id, target_id) == 1 { return values[index].pointer_width_bits; }
        index = index + 1;
    }
    return 0;
}

// An explicit request must never consult the host. This answers whether any
// recorded selection violated that, so the guard checks a compiler-owned fact
// rather than inspecting backend code.
func mir_target_selection_consulted_host(table: MirTargetAuthorityTable[ctx], selection_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirTargetSelection[ctx], ctx] := ctx[table.selections];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].selection_id, selection_id) == 1 { return values[index].consulted_host; }
        index = index + 1;
    }
    return 0;
}

func mir_target_identity_agrees_with_layout(table: MirTargetAuthorityTable[ctx], target_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirTargetIdentity[ctx], ctx] := ctx[table.identities];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].target_id, target_id) == 1 {
            if std.str_eq(values[index].layout_agreement, "agrees_with_phase14_target_layout_authority") == 1 { return 1; }
            return 0;
        }
        index = index + 1;
    }
    return 0;
}

type MirTargetValidation[ctx] struct { valid: int, reason_code: str }
type MirTargetTripleQuery[ctx] struct { found: int, value: MirDeclaredTriple[ctx] }
type MirTargetIdentityQuery[ctx] struct { found: int, value: MirTargetIdentity[ctx] }

func mir_target_table_with_declared_triple(table: MirTargetAuthorityTable[ctx], value: MirDeclaredTriple[ctx], ctx: &Arena) MirTargetAuthorityTable[ctx] { mut values: std.Vector[MirDeclaredTriple[ctx], ctx] := ctx[table.declared_triples]; values.Push(value); ctx.Set(table.declared_triples, values); return table; }

func mir_target_table_with_selection(table: MirTargetAuthorityTable[ctx], value: MirTargetSelection[ctx], ctx: &Arena) MirTargetAuthorityTable[ctx] { mut values: std.Vector[MirTargetSelection[ctx], ctx] := ctx[table.selections]; values.Push(value); ctx.Set(table.selections, values); return table; }

func mir_target_table_with_identity(table: MirTargetAuthorityTable[ctx], value: MirTargetIdentity[ctx], ctx: &Arena) MirTargetAuthorityTable[ctx] { mut values: std.Vector[MirTargetIdentity[ctx], ctx] := ctx[table.identities]; values.Push(value); ctx.Set(table.identities, values); return table; }

func mir_target_declared_triple_for(table: MirTargetAuthorityTable[ctx], target_triple: str, ctx: &Arena) MirTargetTripleQuery[ctx] { mut result: MirTargetTripleQuery[ctx]; result.found = 0; mut values: std.Vector[MirDeclaredTriple[ctx], ctx] := ctx[table.declared_triples]; mut index := 0; while index < len(values) { if std.str_eq(values[index].target_triple, target_triple) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_target_identity_for(table: MirTargetAuthorityTable[ctx], target_id: str, ctx: &Arena) MirTargetIdentityQuery[ctx] { mut result: MirTargetIdentityQuery[ctx]; result.found = 0; mut values: std.Vector[MirTargetIdentity[ctx], ctx] := ctx[table.identities]; mut index := 0; while index < len(values) { if std.str_eq(values[index].target_id, target_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// Validation is the whole point of the authority: an identity that disagrees
// with the layout owner, a triple outside the declared vocabulary, a duplicate
// declaration, or a host probe under an explicit request are all rejections
// rather than warnings.
func mir_target_authority_table_validate(table: MirTargetAuthorityTable[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    mut triples: std.Vector[MirDeclaredTriple[ctx], ctx] := ctx[table.declared_triples];
    mut index := 0;
    while index < len(triples) {
        mut probe := 0;
        while probe < index {
            if std.str_eq(triples[probe].target_triple, triples[index].target_triple) == 1 {
                result.reason_code = std.Clone(ctx, "duplicate_declared_triple");
                return result;
            }
            probe = probe + 1;
        }
        if triples[index].pointer_width_bits != 32 && triples[index].pointer_width_bits != 64 {
            result.reason_code = std.Clone(ctx, "malformed_target_triple");
            return result;
        }
        if std.str_eq(triples[index].endianness, "little") == 0 && std.str_eq(triples[index].endianness, "big") == 0 {
            result.reason_code = std.Clone(ctx, "malformed_target_triple");
            return result;
        }
        index = index + 1;
    }

    mut selections: std.Vector[MirTargetSelection[ctx], ctx] := ctx[table.selections];
    mut selection_index := 0;
    while selection_index < len(selections) {
        mut mode := selections[selection_index].selection_mode;
        if std.str_eq(mode, "explicit_requested_target") == 0 && std.str_eq(mode, "declared_default_target") == 0 {
            result.reason_code = std.Clone(ctx, "ambiguous_target_triple");
            return result;
        }
        if std.str_eq(mode, "explicit_requested_target") == 1 && selections[selection_index].consulted_host == 1 {
            result.reason_code = std.Clone(ctx, "host_inference_under_explicit_target");
            return result;
        }
        if mir_target_triple_is_declared(table, selections[selection_index].requested_triple, ctx) == 0 {
            result.reason_code = std.Clone(ctx, "unknown_target_triple");
            return result;
        }
        selection_index = selection_index + 1;
    }

    mut identities: std.Vector[MirTargetIdentity[ctx], ctx] := ctx[table.identities];
    mut identity_index := 0;
    while identity_index < len(identities) {
        if std.str_eq(identities[identity_index].layout_agreement, "agrees_with_phase14_target_layout_authority") == 0 {
            result.reason_code = std.Clone(ctx, "target_layout_disagreement");
            return result;
        }
        mut declared := mir_target_declared_triple_for(table, identities[identity_index].target_triple, ctx);
        if declared.found == 0 {
            result.reason_code = std.Clone(ctx, "unknown_target_triple");
            return result;
        }
        if declared.value.pointer_width_bits != identities[identity_index].pointer_width_bits {
            result.reason_code = std.Clone(ctx, "target_layout_disagreement");
            return result;
        }
        if std.str_eq(declared.value.endianness, identities[identity_index].endianness) == 0 {
            result.reason_code = std.Clone(ctx, "target_layout_disagreement");
            return result;
        }
        identity_index = identity_index + 1;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}
