# Cranelift Phase 22.3 — Native Implicit-Output Contract

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_native_implicit_output_v1`
- Status: `implementation_complete`
- Next action: `patch22_6_default_route_flip`
- Observed main: `f648de3fb200f83735b0a86ca1d843500c6401aa`
- Predecessor: `phase22_explicit_c_migration_v2`

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
The owning Stdlib relay has merged and Patch 22.3 is complete. The
compiler default remains MIR-to-C; Patch 22.6 is still unchecked and
this reconciliation does not itself authorize a partial route flip.
