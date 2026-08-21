# Cranelift Phase 19 Brand Identity Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_brand_authority.py project`. Do not edit by hand.

Patch 19.2 adds a compiler-owned record during type resolution and
leaves every legacy codegen consumer unchanged. The comparison below
is therefore evidence for the later migration, not a codegen switch.

- Authority version: `phase19_brand_identity_authority_v1`
- Status: `ready_for_patch19_3`
- Identity fields: `brand_origin, arena_identity, is_arena`
- Public boundary policy: `explicit_brand_required`
- Whole-source disagreements: `12`
- Legacy spelling only: `10`
- Resolved arena type only: `2`

## Authority contract

`TypeEnvironment.brand_identities` is populated by `env_resolve_type`.
Its key is the canonical serialized resolved type; its value records
where the brand came from, the arena identity, and whether the resolved
value itself denotes an arena. Suffix spelling is deliberately excluded
from the record and remains available only through the legacy helper.

Public function parameters and returns that resolve to a branded type
must name that brand explicitly. Missing brands produce
`[ImplicitPublicBrand]`; ordinary unbranded values and `&Arena` remain valid.

## Whole-compiler comparison

The projector scans every `compiler/*.gst` declaration with an explicit
type, plus local `Arena.New()` inference. These are every disagreement
between the four-name arena rule and the resolved-type rule in that
declarative surface.

| Source | Binding | Declared/resolved type | Spelling says arena | Record says arena | Reason |
| --- | --- | --- | --- | --- | --- |
| `compiler/mir_array_slice.gst:875` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_array_slice.gst:883` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_array_slice.gst:891` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_array_slice.gst:899` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_enum.gst:834` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_enum.gst:842` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_resource_cfg.gst:146` | `a` | `str` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_resource_cfg_parity_smoke_test_entry.gst:9` | `a` | `str` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_scope_exit_cleanup_parity_smoke_test_entry.gst:164` | `ctx_scope` | `inferred Arena.New()` | `false` | `true` | `arena_type_with_non_legacy_name` |
| `compiler/mir_struct_layout.gst:721` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/mir_struct_layout.gst:729` | `a` | `int` | `true` | `false` | `legacy_name_on_non_arena_type` |
| `compiler/phase19_rename_invariance_renamed_source.gst:14` | `scratch` | `&Arena` | `false` | `true` | `arena_type_with_non_legacy_name` |

The `legacy_name_on_non_arena_type` rows are false positives caused by
ordinary scalar or view parameters named `a`. The
`arena_type_with_non_legacy_name` rows are false negatives: their types
are `Arena`/`&Arena` (or inferred from `Arena.New()`), regardless of name.
