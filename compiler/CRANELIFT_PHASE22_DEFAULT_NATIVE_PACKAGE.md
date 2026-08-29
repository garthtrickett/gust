# Cranelift Phase 22.4 — Default-Native Package and Install Qualification

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_default_native_package_v1`
- Status: `qualification_complete_patch22_2_relay_pending`
- Next action: `patch22_5_explicit_preflip_default_cohort_qualification`
- Observed main: `db4b58bdd78dde41226f9a1e110d555a3c7f5d5d`
- Predecessor: `phase22_native_implicit_output_v1`

## Package

- `gust` — mode `0755` — `self_hosted_compiler`
- `gust-native-backend` — mode `0755` — `executable_relative_native_worker`
- `gust-runtime-package.a` — mode `0644` — `worker_relative_retained_runtime_archive`
- Worker discovery: `absolute_environment_override_or_executable_relative_sibling_only`
- Runtime discovery: `worker_relative_sibling_only`
- PATH search: `forbidden`
- Auto-build/download/fallback: `forbidden`
- Relocation unit: `three_artifact_sibling_directory`

## Qualification

- Compiler default: `mir_to_c_unchanged`
- Default candidate: `explicit_cranelift_with_implicit_output`
- Repository package: `qualified`
- Clean temporary-prefix install: `qualified`
- Relocated install: `qualified`
- Selected native cohort:
  - `compiler/phase10_scalar_return_source.gst` — exit `7` — retained runtime `false`
  - `compiler/phase20_component_allocation_source.gst` — exit `0` — retained runtime `true`
- Explicit C without native components: `byte_identical_and_usable`
- Failure cases: `missing_sibling_worker, missing_runtime_archive, incompatible_sibling_worker`
- Failure output policy: `existing_output_preserved_and_owned_intermediates_removed`
- Oracle: `explicit_mir_to_c`

This is a qualification of the existing three-artifact package, not a
package-layout or default-route change. Patch 22.2–22.4 remain roadmap-open
until the owning Stdlib explicit-C relay lands. Patch 22.5 may continue
through explicit routes; Patch 22.6 remains blocked.
