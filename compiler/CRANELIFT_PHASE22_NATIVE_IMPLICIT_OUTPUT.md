# Cranelift Phase 22.3 — Native Implicit-Output Contract

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_native_implicit_output_v1`
- Status: `implementation_complete_patch22_2_relay_pending`
- Next action: `merge_stdlib_owned_patch22_2_relay_then_mark_22_2_and_22_3_done`
- Observed main: `f648de3fb200f83735b0a86ca1d843500c6401aa`
- Predecessor: `phase22_explicit_c_migration_v1`

## Inferred output

- Selection: `explicit_cranelift_without_explicit_output_only`
- Source suffix: `exact_lowercase_dot_gst`
- Stem derivation: `remove_exactly_one_terminal_dot_gst`
- Directory: `normalized_lexical_source_directory`
- Target executable suffix: `empty_for_all_declared_phase14_elf_and_macho_targets`
- Invalid names: `missing_dot_gst_suffix, empty_stem, dot_stem, dotdot_stem`
- Collision rule: `reject_when_the_derived_output_still_ends_in_dot_gst`
- Explicit `-o`: `opaque_and_authoritative`

## Publication and evidence

- Existing output on success: `phase9g_atomic_replacement`
- Existing output on failure: `preserved_byte_for_byte`
- Directory creation: `forbidden`
- Source route: `same_route_as_equivalent_explicit_output`
- Fallback: `forbidden`
- Inferred/explicit bytes: `identical`
- Observable semantics: `match_mir_to_c_oracle`
- Malformed intent cases: `4`

Patch 22.3 changes only explicit Cranelift output inference. Bare Gust
remains MIR-to-C, the explicit output path remains opaque, and the existing
native source route and Phase 9G transaction retain artifact ownership.
Patch 22.2 and 22.3 remain roadmap-open until the owning Stdlib consumer
relay lands; no later default-flip patch is thereby authorized.
