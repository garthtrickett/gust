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

// ---- Patch 18.2: the complete target support tuple ----
//
// A target is supported only as a complete combination of compiler, runtime
// package, linker, and ABI support. Backend architecture capability is one
// input to the compiler element and is never sufficient on its own; a tuple
// missing any element yields an unsupported decision naming what is absent.

type MirTargetSupportElement[ctx] struct {
    element_kind: str,
    owning_authority: str,
    evidence_id: str,
    present: int,
    compatible: int
}

type MirTargetSupportTuple[ctx] struct {
    tuple_id: str,
    target_id: str,
    compiler_element: MirTargetSupportElement[ctx],
    runtime_package_element: MirTargetSupportElement[ctx],
    linker_element: MirTargetSupportElement[ctx],
    abi_element: MirTargetSupportElement[ctx],
    support_decision: str,
    missing_elements: Index[std.Vector[str, ctx], ctx],
    validation_order_frozen: int
}

func mir_target_make_element(element_kind: str, owning_authority: str, evidence_id: str, present: int, compatible: int, ctx: &Arena) MirTargetSupportElement[ctx] {
    mut element: MirTargetSupportElement[ctx];
    element.element_kind = std.Clone(ctx, element_kind);
    element.owning_authority = std.Clone(ctx, owning_authority);
    element.evidence_id = std.Clone(ctx, evidence_id);
    element.present = present;
    element.compatible = compatible;
    return element;
}

// The frozen validation order. Compiler support is asked first because it is
// the cheapest to refuse, and ABI last because it depends on the target the
// earlier questions establish. A tuple validated in another order has not
// asked the same questions.
func mir_target_tuple_element_order(element_kind: str, ctx: &Arena) int {
    if std.str_eq(element_kind, "compiler") == 1 { return 0; }
    if std.str_eq(element_kind, "runtime_package") == 1 { return 1; }
    if std.str_eq(element_kind, "linker") == 1 { return 2; }
    if std.str_eq(element_kind, "abi") == 1 { return 3; }
    return 99;
}

func mir_target_element_supported(element: MirTargetSupportElement[ctx], ctx: &Arena) int {
    if element.present == 0 { return 0; }
    if element.compatible == 0 { return 0; }
    if std.str_eq(element.owning_authority, "") == 1 { return 0; }
    if std.str_eq(element.evidence_id, "") == 1 { return 0; }
    return 1;
}

// Support is a conjunction, never a disjunction. There is no path here that
// returns supported because one element looked promising.
func mir_target_tuple_is_complete(tuple: MirTargetSupportTuple[ctx], ctx: &Arena) int {
    if mir_target_element_supported(tuple.compiler_element, ctx) == 0 { return 0; }
    if mir_target_element_supported(tuple.runtime_package_element, ctx) == 0 { return 0; }
    if mir_target_element_supported(tuple.linker_element, ctx) == 0 { return 0; }
    if mir_target_element_supported(tuple.abi_element, ctx) == 0 { return 0; }
    return 1;
}

func mir_target_tuple_validate(tuple: MirTargetSupportTuple[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    if tuple.validation_order_frozen == 0 {
        result.reason_code = std.Clone(ctx, "target_support_order_not_frozen");
        return result;
    }
    if mir_target_tuple_element_order(tuple.compiler_element.element_kind, ctx) != 0 ||
       mir_target_tuple_element_order(tuple.runtime_package_element.element_kind, ctx) != 1 ||
       mir_target_tuple_element_order(tuple.linker_element.element_kind, ctx) != 2 ||
       mir_target_tuple_element_order(tuple.abi_element.element_kind, ctx) != 3 {
        result.reason_code = std.Clone(ctx, "target_support_order_drift");
        return result;
    }

    mut complete := mir_target_tuple_is_complete(tuple, ctx);
    mut missing: std.Vector[str, ctx] := ctx[tuple.missing_elements];

    if complete == 1 {
        if std.str_eq(tuple.support_decision, "supported") == 0 {
            result.reason_code = std.Clone(ctx, "target_support_decision_drift");
            return result;
        }
        if len(missing) != 0 {
            result.reason_code = std.Clone(ctx, "target_support_missing_elements_drift");
            return result;
        }
    } else {
        if std.str_eq(tuple.support_decision, "supported") == 1 {
            result.reason_code = std.Clone(ctx, "target_supported_without_complete_tuple");
            return result;
        }
        // An unsupported decision must say what is absent, or it is not a
        // decision, only a refusal.
        if len(missing) == 0 {
            result.reason_code = std.Clone(ctx, "target_unsupported_without_named_missing_elements");
            return result;
        }
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.3: object format, section, and symbol binding ----
//
// The object format is derived from the operating system in the declared target
// identity. It is never taken from a file extension, an output probe, or the
// host the compiler happens to be running on. Section kinds are common across
// formats; only the spelling differs, so the compiler reasons in kinds and the
// descriptor supplies the name.

type MirObjectSection[ctx] struct {
    section_kind: str,
    section_name: str,
    alignment: int
}

type MirObjectFormatDescriptor[ctx] struct {
    target_id: str,
    object_format: str,
    derived_from: str,
    max_section_alignment: int,
    sections: Index[std.Vector[MirObjectSection[ctx], ctx], ctx],
    symbol_bindings: Index[std.Vector[str, ctx], ctx],
    symbol_visibilities: Index[std.Vector[str, ctx], ctx]
}

func mir_object_format_for_operating_system(operating_system: str, ctx: &Arena) str {
    if std.str_eq(operating_system, "linux") == 1 { return std.Clone(ctx, "elf"); }
    if std.str_eq(operating_system, "darwin") == 1 { return std.Clone(ctx, "macho"); }
    return std.Clone(ctx, "");
}

func mir_object_section_declared(descriptor: MirObjectFormatDescriptor[ctx], section_kind: str, ctx: &Arena) int {
    mut values: std.Vector[MirObjectSection[ctx], ctx] := ctx[descriptor.sections];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].section_kind, section_kind) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_object_binding_declared(descriptor: MirObjectFormatDescriptor[ctx], binding: str, ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[descriptor.symbol_bindings];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index], binding) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

// The descriptor must agree with the target identity that produced it. A
// descriptor claiming a format the target's operating system does not imply is
// a host default wearing a descriptor's clothes.
func mir_object_format_validate(descriptor: MirObjectFormatDescriptor[ctx], operating_system: str, ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    mut expected := mir_object_format_for_operating_system(operating_system, ctx);
    if std.str_eq(expected, "") == 1 {
        result.reason_code = std.Clone(ctx, "object_format_unknown_operating_system");
        return result;
    }
    if std.str_eq(descriptor.object_format, expected) == 0 {
        result.reason_code = std.Clone(ctx, "object_format_disagrees_with_target_identity");
        return result;
    }
    if std.str_eq(descriptor.derived_from, "operating_system_in_declared_target_identity") == 0 {
        result.reason_code = std.Clone(ctx, "object_format_not_derived_from_target_identity");
        return result;
    }

    mut sections: std.Vector[MirObjectSection[ctx], ctx] := ctx[descriptor.sections];
    if len(sections) == 0 {
        result.reason_code = std.Clone(ctx, "object_format_declares_no_sections");
        return result;
    }
    mut index := 0;
    while index < len(sections) {
        if sections[index].alignment <= 0 {
            result.reason_code = std.Clone(ctx, "object_section_misaligned");
            return result;
        }
        if sections[index].alignment > descriptor.max_section_alignment {
            result.reason_code = std.Clone(ctx, "object_section_misaligned");
            return result;
        }
        if std.str_eq(sections[index].section_name, "") == 1 {
            result.reason_code = std.Clone(ctx, "object_section_unnamed");
            return result;
        }
        mut probe := 0;
        while probe < index {
            if std.str_eq(sections[probe].section_kind, sections[index].section_kind) == 1 {
                result.reason_code = std.Clone(ctx, "object_section_kind_duplicated");
                return result;
            }
            probe = probe + 1;
        }
        index = index + 1;
    }

    mut bindings: std.Vector[str, ctx] := ctx[descriptor.symbol_bindings];
    if len(bindings) == 0 {
        result.reason_code = std.Clone(ctx, "object_format_declares_no_symbol_bindings");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.4: relocation model and validation ----
//
// A relocation is a compiler-owned decision, not an emitted side effect. Every
// relocation is validated against the declared model before the object is
// published and before the linker is invoked, so an invalid relocation cannot
// replace a valid artifact.

type MirRelocation[ctx] struct {
    relocation_kind: str,
    section_kind: str,
    offset: int,
    addend: int,
    symbol_identity: str
}

type MirRelocationModel[ctx] struct {
    target_id: str,
    object_format: str,
    architecture: str,
    addend_policy: str,
    validation_stage: str,
    relocation_kinds: Index[std.Vector[str, ctx], ctx],
    permitted_section_kinds: Index[std.Vector[str, ctx], ctx]
}

func mir_relocation_kind_declared(model: MirRelocationModel[ctx], relocation_kind: str, ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[model.relocation_kinds];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index], relocation_kind) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_relocation_section_permitted(model: MirRelocationModel[ctx], section_kind: str, ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[model.permitted_section_kinds];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index], section_kind) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

// A relative relocation carries no addend. An absolute one must carry an
// explicit addend, even when that addend is zero, so the value is stated
// rather than inferred from its absence.
func mir_relocation_kind_is_absolute(relocation_kind: str, ctx: &Arena) int {
    if std.str_eq(relocation_kind, "R_X86_64_64") == 1 { return 1; }
    if std.str_eq(relocation_kind, "R_AARCH64_ABS64") == 1 { return 1; }
    if std.str_eq(relocation_kind, "R_386_32") == 1 { return 1; }
    if std.str_eq(relocation_kind, "X86_64_RELOC_UNSIGNED") == 1 { return 1; }
    if std.str_eq(relocation_kind, "ARM64_RELOC_UNSIGNED") == 1 { return 1; }
    return 0;
}

func mir_relocation_validate(model: MirRelocationModel[ctx], relocation: MirRelocation[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    if std.str_eq(model.validation_stage, "before_object_publication_and_before_linker_invocation") == 0 {
        result.reason_code = std.Clone(ctx, "relocation_validated_too_late");
        return result;
    }
    if mir_relocation_kind_declared(model, relocation.relocation_kind, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "relocation_kind_unknown");
        return result;
    }
    // Zero-initialised data holds no bytes, so it can hold no relocation.
    if mir_relocation_section_permitted(model, relocation.section_kind, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "relocation_in_disallowed_section");
        return result;
    }
    if relocation.offset < 0 {
        result.reason_code = std.Clone(ctx, "relocation_offset_malformed");
        return result;
    }
    if mir_relocation_kind_is_absolute(relocation.relocation_kind, ctx) == 0 {
        if relocation.addend != 0 {
            result.reason_code = std.Clone(ctx, "relocation_addend_malformed");
            return result;
        }
    }
    if std.str_eq(relocation.symbol_identity, "") == 1 {
        result.reason_code = std.Clone(ctx, "relocation_symbol_missing");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.5: target-specific ABI selection ----
//
// Phase 18 selects an ABI the Phase 16 authority already accepts. It never
// defines placement, classification, or transport, and a target may not select
// a platform calling convention Phase 16 does not offer.

type MirTargetAbiSelection[ctx] struct {
    target_id: str,
    selected_abi_id: str,
    owning_authority: str,
    compatibility_decision: str,
    platform_convention_status: str
}

func mir_target_abi_selection_validate(selection: MirTargetAbiSelection[ctx], accepted_abi_id: str, ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;
    if std.str_eq(selection.selected_abi_id, accepted_abi_id) == 0 {
        result.reason_code = std.Clone(ctx, "target_abi_undeclared_by_phase16");
        return result;
    }
    if std.str_eq(selection.owning_authority, "") == 1 {
        result.reason_code = std.Clone(ctx, "target_abi_selection_missing");
        return result;
    }
    if std.str_eq(selection.compatibility_decision, "compatible") == 0 &&
       std.str_eq(selection.compatibility_decision, "incompatible") == 0 {
        result.reason_code = std.Clone(ctx, "target_abi_incompatible");
        return result;
    }
    // Claiming a platform convention would be selecting something Phase 16 does
    // not own, which is Phase 18 defining ABI semantics.
    if std.str_eq(selection.platform_convention_status, "deferred_to_a_later_abi_phase") == 0 {
        result.reason_code = std.Clone(ctx, "target_abi_platform_convention_selected_without_phase16_support");
        return result;
    }
    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.6: target-specific runtime package selection ----
//
// Phase 18 selects a package Phase 17 already built for the target. It never
// defines runtime symbol identity or version, and the selected package's object
// format must agree with the format Patch 18.3 derived for that target.

type MirTargetPackageSelection[ctx] struct {
    target_id: str,
    selected_package_version: str,
    package_form: str,
    owning_authority: str,
    declared_object_format: str,
    compatibility_decision: str
}

func mir_target_package_selection_validate(selection: MirTargetPackageSelection[ctx], descriptor_format: str, ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;
    if std.str_eq(selection.selected_package_version, "") == 1 {
        result.reason_code = std.Clone(ctx, "target_package_missing");
        return result;
    }
    if std.str_eq(selection.owning_authority, "phase17_runtime_package_authority") == 0 {
        result.reason_code = std.Clone(ctx, "target_package_defined_by_phase18");
        return result;
    }
    // The package format must agree with the format Patch 18.3 derived from the
    // target's operating system, or the package belongs to a different target.
    if std.str_eq(selection.declared_object_format, descriptor_format) == 0 {
        result.reason_code = std.Clone(ctx, "target_package_object_format_mismatch");
        return result;
    }
    if std.str_eq(selection.package_form, "static_archive") == 0 &&
       std.str_eq(selection.package_form, "shared_library") == 0 {
        result.reason_code = std.Clone(ctx, "target_package_wrong_target");
        return result;
    }
    if std.str_eq(selection.compatibility_decision, "compatible") == 0 &&
       std.str_eq(selection.compatibility_decision, "incompatible") == 0 {
        result.reason_code = std.Clone(ctx, "target_package_incompatible");
        return result;
    }
    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.7: linker discovery and invocation policy ----
//
// Discovery is ordered and deterministic. The CC environment variable stays
// available, but as a validated step in that order rather than an unvalidated
// escape hatch: whatever it names must still satisfy the descriptor. Phase 18
// plans the invocation; Phase 9G executes it.

type MirLinkerDescriptor[ctx] struct {
    linker_id: str,
    target_id: str,
    driver_name: str,
    discovery_result: str,
    supported_object_format: str,
    invocation_owner: str,
    probe_argument: str
}

func mir_linker_argument_permitted(argument: str, ctx: &Arena) int {
    if std.str_eq(argument, "-o") == 1 { return 1; }
    if std.str_eq(argument, "output_path") == 1 { return 1; }
    if std.str_eq(argument, "object_inputs") == 1 { return 1; }
    if std.str_eq(argument, "runtime_package_path") == 1 { return 1; }
    return 0;
}

func mir_linker_descriptor_validate(descriptor: MirLinkerDescriptor[ctx], target_format: str, ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    // An undiscovered linker can be reported but never used.
    if std.str_eq(descriptor.discovery_result, "discovered") == 0 {
        result.reason_code = std.Clone(ctx, "linker_undiscovered");
        return result;
    }
    if std.str_eq(descriptor.supported_object_format, target_format) == 0 {
        result.reason_code = std.Clone(ctx, "linker_unsupported_object_format");
        return result;
    }
    // Phase 9G owns execution. Phase 18 producing an invocation itself would
    // take artifact ownership the earlier phase already holds.
    if std.str_eq(descriptor.invocation_owner, "phase9g_artifact_planner") == 0 {
        result.reason_code = std.Clone(ctx, "linker_invoked_by_phase18");
        return result;
    }
    if mir_linker_argument_permitted(descriptor.probe_argument, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "linker_argument_outside_vocabulary");
        return result;
    }
    if std.str_eq(descriptor.driver_name, "") == 1 {
        result.reason_code = std.Clone(ctx, "linker_target_mismatch");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.8: static and dynamic runtime linking modes ----
//
// A mode is available only when a runtime package form provides it. Every
// declared package is a static archive today, so dynamic is unavailable and a
// request for it is refused rather than quietly downgraded to static.

type MirLinkModeDecision[ctx] struct {
    target_id: str,
    required_package_form: str,
    selected_mode: str
}

func mir_link_mode_for_package_form(package_form: str, ctx: &Arena) str {
    if std.str_eq(package_form, "static_archive") == 1 { return std.Clone(ctx, "static"); }
    if std.str_eq(package_form, "shared_library") == 1 { return std.Clone(ctx, "dynamic"); }
    return std.Clone(ctx, "");
}

func mir_link_mode_validate(decision: MirLinkModeDecision[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    // A package form that provides no mode cannot back any link.
    mut available := mir_link_mode_for_package_form(decision.required_package_form, ctx);
    if std.str_eq(available, "") == 1 {
        result.reason_code = std.Clone(ctx, "link_mode_package_form_mismatch");
        return result;
    }
    if std.str_eq(decision.selected_mode, "static") == 0 &&
       std.str_eq(decision.selected_mode, "dynamic") == 0 {
        result.reason_code = std.Clone(ctx, "link_mode_unknown");
        return result;
    }
    // The selected mode must be the one the package form actually provides.
    // Falling back to another mode would be a silent substitution.
    if std.str_eq(decision.selected_mode, available) == 0 {
        result.reason_code = std.Clone(ctx, "link_mode_unavailable_for_target");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.9: cross-compilation policy and host/target separation ----
//
// A pair is cross exactly when the target triple differs from the host triple.
// A cross pair may be declared only when its linker was discovered; declaring
// one that cannot link would be a claim without evidence. Every cross candidate
// ends in exactly one defensible state: declared with a linker, or undeclared
// with a stated blocker.

type MirHostTargetPair[ctx] struct {
    host_triple: str,
    target_triple: str,
    linker_discovered: int,
    declared: int,
    blocking_reason: str
}

func mir_cross_classification(host_triple: str, target_triple: str, ctx: &Arena) str {
    if std.str_eq(host_triple, target_triple) == 1 { return std.Clone(ctx, "native"); }
    return std.Clone(ctx, "cross");
}

func mir_host_target_pair_validate(pair: MirHostTargetPair[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    mut classification := mir_cross_classification(pair.host_triple, pair.target_triple, ctx);
    mut is_cross := 0;
    if std.str_eq(classification, "cross") == 1 { is_cross = 1; }

    if pair.declared == 1 {
        // A native pair is not a cross pair, and a declared pair must have a
        // linker and cannot simultaneously carry a blocker.
        if is_cross == 0 {
            result.reason_code = std.Clone(ctx, "cross_pair_undeclared");
            return result;
        }
        if pair.linker_discovered == 0 {
            result.reason_code = std.Clone(ctx, "cross_pair_incomplete_tuple");
            return result;
        }
        if std.str_eq(pair.blocking_reason, "") == 0 {
            result.reason_code = std.Clone(ctx, "cross_pair_undeclared");
            return result;
        }
    } else {
        // An undeclared cross candidate must say what blocks it.
        if is_cross == 1 && std.str_eq(pair.blocking_reason, "") == 1 {
            result.reason_code = std.Clone(ctx, "cross_pair_undeclared");
            return result;
        }
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.10: unsupported-target detection and diagnostics ----
//
// An unsupported target names the tuple elements it actually lacks and is
// refused before driver discovery. A refusal that does not say what is missing
// is not a diagnostic, and a supported target carries no rejection class.

type MirTargetDiagnostic[ctx] struct {
    target_id: str,
    support_decision: str,
    missing_element: str,
    rejection_class: str,
    failure_stage: str
}

func mir_target_diagnostic_validate(diagnostic: MirTargetDiagnostic[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    // A refusal after output could already exist cannot preserve it.
    if std.str_eq(diagnostic.failure_stage, "before_driver_discovery") == 0 {
        result.reason_code = std.Clone(ctx, "target_diagnostic_refused_too_late");
        return result;
    }

    if std.str_eq(diagnostic.support_decision, "supported") == 1 {
        // A supported target has nothing to refuse.
        if std.str_eq(diagnostic.rejection_class, "") == 0 {
            result.reason_code = std.Clone(ctx, "target_diagnostic_supported_with_rejection");
            return result;
        }
        if std.str_eq(diagnostic.missing_element, "") == 0 {
            result.reason_code = std.Clone(ctx, "target_diagnostic_supported_with_rejection");
            return result;
        }
    } else {
        // An unsupported target must say both what is missing and why.
        if std.str_eq(diagnostic.rejection_class, "") == 1 {
            result.reason_code = std.Clone(ctx, "target_diagnostic_generic_refusal");
            return result;
        }
        if std.str_eq(diagnostic.missing_element, "") == 1 {
            result.reason_code = std.Clone(ctx, "target_diagnostic_generic_refusal");
            return result;
        }
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.11: symbol and relocation inspection evidence ----
//
// Inspection observes and compares; it never decides. An observed symbol,
// binding, section, or relocation kind must trace to a compiler-produced
// record. Inspection supplying a fact the compiler did not produce would make
// the object file a second source of truth.

type MirObjectObservation[ctx] struct {
    symbol_name: str,
    binding: str,
    section_kind: str,
    relocation_kind: str,
    in_compiler_plan: int
}

func mir_object_binding_is_declared(binding: str, ctx: &Arena) int {
    if std.str_eq(binding, "local") == 1 { return 1; }
    if std.str_eq(binding, "global") == 1 { return 1; }
    if std.str_eq(binding, "weak") == 1 { return 1; }
    return 0;
}

func mir_object_section_is_declared(section_kind: str, ctx: &Arena) int {
    if std.str_eq(section_kind, "text") == 1 { return 1; }
    if std.str_eq(section_kind, "read_only_data") == 1 { return 1; }
    if std.str_eq(section_kind, "data") == 1 { return 1; }
    if std.str_eq(section_kind, "zero_initialised_data") == 1 { return 1; }
    return 0;
}

func mir_object_observation_validate(observation: MirObjectObservation[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    // A symbol the compiler never planned would make the object a second
    // source of truth.
    if observation.in_compiler_plan == 0 {
        result.reason_code = std.Clone(ctx, "inspected_symbol_not_in_compiler_plan");
        return result;
    }
    if mir_object_binding_is_declared(observation.binding, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "inspected_binding_outside_declared_vocabulary");
        return result;
    }
    if mir_object_section_is_declared(observation.section_kind, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "inspected_section_outside_declared_vocabulary");
        return result;
    }
    // Zero-initialised data holds no bytes, so an observed relocation there is
    // a real defect rather than a vocabulary question.
    if std.str_eq(observation.section_kind, "zero_initialised_data") == 1 {
        result.reason_code = std.Clone(ctx, "inspected_relocation_in_disallowed_section");
        return result;
    }
    if mir_relocation_kind_is_absolute(observation.relocation_kind, ctx) == 0 &&
       std.str_eq(observation.relocation_kind, "R_X86_64_PC32") == 0 &&
       std.str_eq(observation.relocation_kind, "R_X86_64_PLT32") == 0 {
        result.reason_code = std.Clone(ctx, "inspected_relocation_kind_not_in_model");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.12: debug information strategy ----
//
// The debug plan is compiler-selected and derived from the object format. A
// plan must say what it emits and what it does not; a record kind cannot be
// both promised and disclaimed, and a plan that states only its inclusions
// leaves its gaps implicit.

type MirDebugPlan[ctx] struct {
    target_id: str,
    debug_format: str,
    derived_from: str,
    debug_level: str,
    included_kind: str,
    excluded_kind: str
}

func mir_debug_level_is_declared(level: str, ctx: &Arena) int {
    if std.str_eq(level, "none") == 1 { return 1; }
    if std.str_eq(level, "line_tables_only") == 1 { return 1; }
    return 0;
}

func mir_debug_plan_validate(plan: MirDebugPlan[ctx], ctx: &Arena) MirTargetValidation[ctx] {
    mut result: MirTargetValidation[ctx];
    result.valid = 0;

    // A plan the backend inferred is not a compiler-selected plan.
    if std.str_eq(plan.derived_from, "object_format_in_the_phase18_object_format_authority") == 0 {
        result.reason_code = std.Clone(ctx, "debug_plan_inferred_by_backend");
        return result;
    }
    if mir_debug_level_is_declared(plan.debug_level, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "debug_level_unknown");
        return result;
    }
    if std.str_eq(plan.debug_format, "dwarf") == 0 {
        result.reason_code = std.Clone(ctx, "debug_format_disagrees_with_object_format");
        return result;
    }
    if std.str_eq(plan.included_kind, "") == 1 {
        result.reason_code = std.Clone(ctx, "debug_record_kind_undeclared");
        return result;
    }
    // A plan that says nothing about what it omits leaves its gaps implicit.
    if std.str_eq(plan.excluded_kind, "") == 1 {
        result.reason_code = std.Clone(ctx, "debug_record_kind_undeclared");
        return result;
    }
    // A record kind both promised and disclaimed is a contradiction.
    if std.str_eq(plan.included_kind, plan.excluded_kind) == 1 {
        result.reason_code = std.Clone(ctx, "debug_record_kind_undeclared");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.13: source location preservation ----
//
// A source location is produced by the compiler and survives lowering wherever
// the debug plan requires it. Inventing a plausible span for code the source did
// not write is worse than admitting the gap: a debugger will then point
// confidently at the wrong line, which is harder to diagnose than no line at all.
//
// Two of the rejections below are properties of a SET of locations rather than
// of any one location, so they need a validator over the whole vector. A single
// record cannot tell whether it duplicates another, and an absent location
// cannot reject itself.

type MirSourceLocation[ctx] struct {
    source_file: str,
    source_span: str,
    canonical_mir_association: str,
    emitted_debug_association: str,
    fabricated: int
}

type MirSourceLocationValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_source_location_validate(location: MirSourceLocation[ctx], ctx: &Arena) MirSourceLocationValidation[ctx] {
    mut result: MirSourceLocationValidation[ctx];
    result.valid = 0;

    // A fabricated location, or one carrying no span, has no source to point at.
    if location.fabricated == 1 || std.str_eq(location.source_span, "") == 1 ||
       std.str_eq(location.source_file, "") == 1 {
        result.reason_code = std.Clone(ctx, "source_location_fabricated_without_a_source_span");
        return result;
    }

    // No canonical MIR association means the backend produced this, not the
    // compiler. The production policy forbids backend-reconstructed locations.
    if std.str_eq(location.canonical_mir_association, "") == 1 {
        result.reason_code = std.Clone(ctx, "source_location_reconstructed_by_backend");
        return result;
    }

    // Present in canonical MIR but absent from the emitted records: lost.
    if std.str_eq(location.emitted_debug_association, "") == 1 {
        result.reason_code = std.Clone(ctx, "source_location_lost_in_lowering");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// Validates a whole set of locations against what the debug plan requires.
// `requires_locations` is 1 when the plan for this target emits a line table.
func mir_source_location_set_validate(locations: Index[std.Vector[MirSourceLocation[ctx], ctx], ctx], requires_locations: int, ctx: &Arena) MirSourceLocationValidation[ctx] {
    mut result: MirSourceLocationValidation[ctx];
    result.valid = 0;
    mut values: std.Vector[MirSourceLocation[ctx], ctx] := ctx[locations];

    // The plan asks for a line table and nothing was produced to fill it.
    if requires_locations == 1 && len(values) == 0 {
        result.reason_code = std.Clone(ctx, "source_location_missing_where_the_debug_plan_requires_it");
        return result;
    }

    mut index := 0;
    while index < len(values) {
        mut single := mir_source_location_validate(values[index], ctx);
        if single.valid == 0 {
            result.reason_code = std.Clone(ctx, single.reason_code);
            return result;
        }

        // One instruction carries at most one location. Two locations naming the
        // same canonical MIR instruction make the emitted line table ambiguous.
        mut probe := 0;
        while probe < index {
            if std.str_eq(values[probe].canonical_mir_association,
                          values[index].canonical_mir_association) == 1 {
                result.reason_code = std.Clone(ctx, "source_location_duplicated_for_one_instruction");
                return result;
            }
            probe = probe + 1;
        }
        index = index + 1;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.14: optimisation level policy ----
//
// A level may change the emitted instruction sequence, code size, compile time,
// or debug record density. It may never change observable program behaviour.
// The unoptimised level must actually be unoptimised, or the comparison it
// anchors is between two optimised builds and proves nothing.
//
// The compiler selects the level and carries it in the native request. A level
// the backend chose for itself is a decision taken from the compiler.

type MirOptimisationDecision[ctx] struct {
    target_id: str,
    selected_level: str,
    transformation: str,
    selected_by: str,
    observable_behaviour_changed: int,
    line_table_preserved: int
}

type MirOptimisationValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_optimisation_level_is_declared(level: str, ctx: &Arena) int {
    if std.str_eq(level, "none") == 1 { return 1; }
    if std.str_eq(level, "basic") == 1 { return 1; }
    return 0;
}

// Only the transformations the level declares may appear under it. The
// unoptimised level declares none at all.
func mir_optimisation_transformation_is_declared(level: str, transformation: str, ctx: &Arena) int {
    if std.str_eq(level, "none") == 1 { return 0; }
    if std.str_eq(transformation, "dead_code_elimination") == 1 { return 1; }
    if std.str_eq(transformation, "constant_folding") == 1 { return 1; }
    if std.str_eq(transformation, "redundant_move_elimination") == 1 { return 1; }
    return 0;
}

func mir_optimisation_decision_validate(decision: MirOptimisationDecision[ctx], ctx: &Arena) MirOptimisationValidation[ctx] {
    mut result: MirOptimisationValidation[ctx];
    result.valid = 0;

    if mir_optimisation_level_is_declared(decision.selected_level, ctx) == 0 {
        result.reason_code = std.Clone(ctx, "optimisation_level_unknown");
        return result;
    }
    // The compiler selects the level; a backend-selected level takes a decision
    // the compiler already owns.
    if std.str_eq(decision.selected_by, "compiler") == 0 {
        result.reason_code = std.Clone(ctx, "optimisation_level_selected_by_backend");
        return result;
    }
    // The unoptimised level carrying a transformation is the case that quietly
    // destroys the baseline: the anchor build is optimised and nobody notices.
    if std.str_eq(decision.transformation, "") == 0 {
        if mir_optimisation_transformation_is_declared(decision.selected_level, decision.transformation, ctx) == 0 {
            result.reason_code = std.Clone(ctx, "optimisation_level_transformation_undeclared");
            return result;
        }
    }
    if decision.observable_behaviour_changed == 1 {
        result.reason_code = std.Clone(ctx, "optimisation_level_changed_observable_behaviour");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}
// A level may reshape the instruction sequence, but the debug plan's promises
// must survive that reshaping. A transformation that moves or removes
// instructions without updating the line table silently invalidates every
// record the plan claims to emit, so the decision must carry that evidence
// rather than let a consumer assume it.
func mir_optimisation_debug_compatible(decision: MirOptimisationDecision[ctx], debug_level: str, ctx: &Arena) MirOptimisationValidation[ctx] {
    mut result: MirOptimisationValidation[ctx];
    result.valid = 0;

    // Only a plan that emits a line table can have one invalidated.
    if std.str_eq(debug_level, "line_tables_only") == 1 &&
       std.str_eq(decision.selected_level, "none") == 0 &&
       decision.line_table_preserved == 0 {
        result.reason_code = std.Clone(ctx, "optimisation_level_incompatible_with_debug_plan");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// ---- Patch 18.15: reproducible output ----
//
// Two builds of the same source, target, level, and debug plan must produce the
// same bytes in every field declared reproducible. Fields that are not a
// property of the input -- wall clock, the path the build ran from, where the
// compiler binary happens to live -- are excluded BY NAME with a reason, rather
// than being quietly normalised away.
//
// Reproducibility is claimed only after a repeated build has actually been
// compared. A claim made from a single build is a claim about nothing.

type MirReproducibleBuild[ctx] struct {
    target_id: str,
    optimisation_level: str,
    debug_plan: str,
    reproducible_field_value: str,
    excluded_field_reason: str,
    repeated_build_compared: int,
    embedded_path_form: str,
    order_source: str
}

type MirReproducibilityValidation[ctx] struct {
    valid: int,
    reason_code: str
}

// Validates a SINGLE build record before any comparison happens. A build that
// does not declare the inputs reproducibility is defined over cannot be
// compared against anything: the optimisation level and the debug plan both
// change emitted bytes, so a build naming neither has not stated what it is a
// build OF. That is an undeclared input, not a field that varied -- calling it
// a variance would make the compiler confidently wrong about why it refused.
func mir_reproducible_build_validate(build: MirReproducibleBuild[ctx], ctx: &Arena) MirReproducibilityValidation[ctx] {
    mut result: MirReproducibilityValidation[ctx];
    result.valid = 0;

    if build.repeated_build_compared == 0 {
        result.reason_code = std.Clone(ctx, "reproducibility_claimed_without_a_repeated_build");
        return result;
    }
    // Excluding a field without saying why is indistinguishable from hiding a
    // nondeterminism.
    if std.str_eq(build.excluded_field_reason, "") == 1 {
        result.reason_code = std.Clone(ctx, "excluded_field_not_declared");
        return result;
    }
    if std.str_eq(build.optimisation_level, "") == 1 || std.str_eq(build.debug_plan, "") == 1 {
        result.reason_code = std.Clone(ctx, "reproducibility_input_undeclared");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

func mir_reproducibility_validate(first: MirReproducibleBuild[ctx], second: MirReproducibleBuild[ctx], ctx: &Arena) MirReproducibilityValidation[ctx] {
    mut result: MirReproducibilityValidation[ctx];
    result.valid = 0;

    // A reproducibility claim that never compared a second build is not evidence.
    if first.repeated_build_compared == 0 || second.repeated_build_compared == 0 {
        result.reason_code = std.Clone(ctx, "reproducibility_claimed_without_a_repeated_build");
        return result;
    }
    if std.str_eq(first.reproducible_field_value, second.reproducible_field_value) == 0 {
        result.reason_code = std.Clone(ctx, "reproducible_field_varied_between_builds");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}

// An excluded field must carry the reason it is excluded. Excluding a field
// without saying why is indistinguishable from hiding a nondeterminism.
func mir_reproducibility_exclusion_validate(build: MirReproducibleBuild[ctx], ctx: &Arena) MirReproducibilityValidation[ctx] {
    mut result: MirReproducibilityValidation[ctx];
    result.valid = 0;

    if std.str_eq(build.excluded_field_reason, "") == 1 {
        result.reason_code = std.Clone(ctx, "excluded_field_not_declared");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}
// The remaining two rejections are properties the build must declare rather
// than properties a consumer could infer from the bytes. Gust has no string
// prefix helper, and inferring "this path is absolute" from a leading slash
// would be exactly the kind of consumer-side inference this phase bans: the
// build states the form it used, and the validator checks that statement
// against the declared normalisation rules.
func mir_reproducibility_normalisation_validate(build: MirReproducibleBuild[ctx], ctx: &Arena) MirReproducibilityValidation[ctx] {
    mut result: MirReproducibilityValidation[ctx];
    result.valid = 0;

    // Rule: embedded paths are recorded relative to the source root.
    if std.str_eq(build.embedded_path_form, "relative_to_source_root") == 0 {
        result.reason_code = std.Clone(ctx, "normalisation_rule_not_applied");
        return result;
    }

    // Rule: order in a reproducible field comes from compiler-produced order,
    // never from a hash table walk or a filesystem listing.
    if std.str_eq(build.order_source, "compiler_produced_order") == 0 {
        result.reason_code = std.Clone(ctx, "nondeterministic_order_in_a_reproducible_field");
        return result;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "ok");
    return result;
}
