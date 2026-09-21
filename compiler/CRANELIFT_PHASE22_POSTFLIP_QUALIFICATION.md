# Cranelift Phase 22.7 — Post-flip Qualification

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_postflip_qualification_v1`
- Status: `qualification_complete`
- Next patch: `22.8`
- Observed main: `ea0d8111fec4160ec5718241a5e15cb418e519b6`
- Predecessor: `phase22_default_route_seed_convergence_v1`

## Delivery

- Make default goal: `phase10-native-package`
- Compiler default: `cranelift`
- Package: `gust, gust-native-backend, gust-runtime-package.a`
- Install/relocation unit: `three_artifact_sibling_directory`
- Explicit C spellings: `c, mir-to-c`
- Explicit C role: `semantic_oracle_bootstrap_and_operator_selected_rollback`
- Fallback: `forbidden`
- Bootstrap route: `explicit_mir_to_c`

## Qualification

- repository_package_bare_default: `qualified`
- installed_package_bare_default: `qualified`
- relocated_package_bare_default: `qualified`
- bare_and_explicit_native: `artifact_and_behavior_identical`
- explicit_c_spellings: `byte_identical_and_executable`
- missing_native_worker: `bare_default_fails_without_fallback_and_explicit_c_succeeds`
- documentation_and_help: `cranelift_default_explicit_c_oracle_no_fallback`
- release_shape: `exact_three_artifact_sibling_package`

## Native workflow dependencies

- `gust_v4.c`
- `compiler/*.gst`
- `compiler/experiments/cranelift/**`
- `src/runtime.c`
- `src/runtime/**`
- `tools/normalize_generated_arena_offsets.py`

Every listed input is present in both pull-request and main-push path
filters of every owning Phase 22 native qualification workflow.
Explicit C is the named oracle and rollback route; native failure never
selects it automatically. This patch adds no Gust semantics, canonical
MIR/lowering, ABI/layout/runtime-symbol, target/linker, seed, or Stdlib
change, and does not begin Patch 22.8.
