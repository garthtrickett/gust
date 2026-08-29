# Cranelift Phase 22 Opening — Default Route and Consumer Inventory

Generated from `scripts/cranelift_feature_registry.json` and the live
repository invocation scan by `scripts/phase22_opening.py project`.
Do not edit by hand.

- Contract: `phase22_opening_v2`
- Status: `patch22_1_complete`
- Next patch: `22.2`
- Observed main: `c157c86674624fd298c2f65e98ed8f4df85cb175`
- Executable compiler invocations: `269`
- Unclassified invocations: `0`

## Current CLI and package

- Bare route: `mir_to_c`
- Bare artifact: `C_source_on_stdout`
- Explicit `mir-to-c`: `mir_to_c`
- Explicit `c`: `rejected_unknown_backend`
- Cranelift requires `-o`: `true`
- Package artifacts: `gust, gust-native-backend, gust-runtime-package.a`

## Documentation and workflow surfaces

- `native_backend_readme` — `MIR_to_C_default_Cranelift_explicit_experimental_and_requires_o`; transition `22.6_and_22.7`
- `one_way_ledger` — `records_mir_to_c_and_explicit_cranelift_cli`; transition `22.7`
- `roadmap_tail` — `declares_phase22_default_native_and_retained_backend_c`; transition `22.2_through_22.9`
- `root_readme` — `documents_C_bootstrap_chain_without_a_default_backend_user_contract`; transition `22.7_preserve_bootstrap_claim_and_add_user_default`
- `pr_fast` — `parallel_focused_guards_with_no_phase22_default_contract`; transition `22.1_contract_then_22.7_default_release_smoke`
- `heavy_guards` — `parallel_heavy_guards_built_from_current_default_C_compiler`; transition `22.7_default_and_explicit_C_qualification`
- `historical_full` — `daily_registry_derived_level3_owner_at_03_23_UTC`; transition `22.8_one_exact_final_main_success`

## Invocation summary

- Selection `explicit_c`: `80`
- Selection `explicit_cranelift`: `104`
- Selection `explicit_invalid_or_parser_probe`: `2`
- Selection `implicit_default`: `83`
- Consumer class `already_explicit_or_parser_probe`: `186`
- Consumer class `bootstrap_and_final_compiler_C_generation`: `5`
- Consumer class `cranelift_C_or_diagnostic_guard`: `40`
- Consumer class `developer_generated_C_pipeline`: `1`
- Consumer class `help_surface_probe`: `2`
- Consumer class `intentional_default_selection_probe`: `3`
- Consumer class `invocation_parser_probe`: `2`
- Consumer class `repository_C_or_diagnostic_guard`: `15`
- Consumer class `stdlib_owned_C_or_diagnostic_guard`: `15`

## Executable invocation inventory

| Path | Line | Recipe | Selection | Class | Owner | Expected transition | Falsifier |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| `Makefile` | 49 | `none` | `implicit_default` | `bootstrap_and_final_compiler_C_generation` | `cranelift` | `22.2_explicit_mir_to_c_before_default_flip` | `default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration` |
| `Makefile` | 103 | `none` | `implicit_default` | `bootstrap_and_final_compiler_C_generation` | `cranelift` | `22.2_explicit_mir_to_c_before_default_flip` | `default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration` |
| `Makefile` | 136 | `none` | `implicit_default` | `bootstrap_and_final_compiler_C_generation` | `cranelift` | `22.2_explicit_mir_to_c_before_default_flip` | `default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration` |
| `Makefile` | 235 | `none` | `implicit_default` | `bootstrap_and_final_compiler_C_generation` | `cranelift` | `22.2_explicit_mir_to_c_before_default_flip` | `default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration` |
| `Makefile` | 239 | `none` | `implicit_default` | `bootstrap_and_final_compiler_C_generation` | `cranelift` | `22.2_explicit_mir_to_c_before_default_flip` | `default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration` |
| `justfile` | 9155 | `guard-cranelift-phase10-backend-selection-contract` | `implicit_default` | `intentional_default_selection_probe` | `cranelift` | `22.6_flip_expectation_only` | `probe_is_migrated_before_the_default_route_changes` |
| `justfile` | 9156 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9157 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9163 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9177 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9210 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9214 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_invalid_or_parser_probe` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9218 | `guard-cranelift-phase10-backend-selection-contract` | `implicit_default` | `invocation_parser_probe` | `cranelift` | `preserve_shared_parser_diagnostic` | `backend_migration_changes_a_pre_backend_parser_diagnostic` |
| `justfile` | 9222 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_invalid_or_parser_probe` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9226 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9230 | `guard-cranelift-phase10-backend-selection-contract` | `implicit_default` | `invocation_parser_probe` | `cranelift` | `preserve_shared_parser_diagnostic` | `backend_migration_changes_a_pre_backend_parser_diagnostic` |
| `justfile` | 9234 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9238 | `guard-cranelift-phase10-backend-selection-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 9299 | `guard-cranelift-phase10-output-contract` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 10676 | `guard-cranelift-phase11-scalar-expression-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 10678 | `guard-cranelift-phase11-scalar-expression-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 10700 | `guard-cranelift-phase11-scalar-expression-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 10748 | `guard-cranelift-phase11-scalar-expression-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 10772 | `guard-cranelift-phase11-scalar-expression-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 10967 | `guard-cranelift-phase11-local-state-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 10970 | `guard-cranelift-phase11-local-state-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11008 | `guard-cranelift-phase11-local-state-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11073 | `guard-cranelift-phase11-local-state-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11294 | `guard-cranelift-phase11-structured-cfg-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 11297 | `guard-cranelift-phase11-structured-cfg-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11333 | `guard-cranelift-phase11-structured-cfg-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11412 | `guard-cranelift-phase11-structured-cfg-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11754 | `guard-cranelift-phase11-block-parameter-loop-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 11758 | `guard-cranelift-phase11-block-parameter-loop-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 11795 | `guard-cranelift-phase11-block-parameter-loop-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12196 | `guard-cranelift-phase11-direct-call-abi-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 12197 | `guard-cranelift-phase11-direct-call-abi-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12204 | `guard-cranelift-phase11-direct-call-abi-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12226 | `guard-cranelift-phase11-direct-call-abi-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12526 | `guard-cranelift-phase11-module-import-runtime-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 12530 | `guard-cranelift-phase11-module-import-runtime-parity` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12567 | `guard-cranelift-phase11-module-import-runtime-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 12631 | `guard-cranelift-phase11-module-import-runtime-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 13000 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 13123 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 13125 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 13186 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 13225 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 13270 | `guard-cranelift-phase11-metadata-diagnostic-parity` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `justfile` | 22060 | `guard-mir-feature-return-int-preservation` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22099 | `guard-mir-feature-local-binding-read-preservation` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22139 | `guard-mir-feature-if-else-return-int-preservation` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22178 | `guard-mir-feature-local-binding-read-provenance-metadata-preservation` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22734 | `run-step52-positive-batch` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22807 | `make-test-suite` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 22847 | `make-test-suite-parallel` | `implicit_default` | `repository_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `justfile` | 23136 | `guard-stdlib-s1-str-equality-diagnostic` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23137 | `guard-stdlib-s1-str-equality-diagnostic` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23151 | `guard-stdlib-s1-str-equality-diagnostic` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23183 | `guard-stdlib-s1-collection-receivers` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23187 | `guard-stdlib-s1-collection-receivers` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23194 | `guard-stdlib-s1-collection-receivers` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23195 | `guard-stdlib-s1-collection-receivers` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23277 | `guard-stdlib-s1-resource-prerequisites` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/phase12_5_route_architecture.sh` | 65 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase12_5_route_architecture.sh` | 116 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase12_5_route_architecture.sh` | 187 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase12_5_route_architecture.sh` | 255 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase12_5_route_architecture.sh` | 294 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_broader_imported_runtime_calls.sh` | 175 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_broader_imported_runtime_calls.sh` | 179 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_broader_imported_runtime_calls.sh` | 197 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_broader_imported_runtime_calls.sh` | 295 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_capability_deferral.sh` | 87 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_capability_deferral.sh` | 88 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_capability_deferral.sh` | 104 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_capability_deferral.sh` | 144 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_capability_deferral.sh` | 198 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_capability_deferral.sh` | 269 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_direct_call_graph.sh` | 169 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_direct_call_graph.sh` | 172 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_direct_call_graph.sh` | 188 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_direct_call_graph.sh` | 258 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_general_loop.sh` | 173 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_general_loop.sh` | 180 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_general_loop.sh` | 200 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_general_loop.sh` | 277 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_multiple_locals_assignments.sh` | 144 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_multiple_locals_assignments.sh` | 151 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_multiple_locals_assignments.sh` | 171 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_multiple_locals_assignments.sh` | 253 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_nested_structured_cfg.sh` | 169 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_nested_structured_cfg.sh` | 176 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_nested_structured_cfg.sh` | 196 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_nested_structured_cfg.sh` | 273 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_parameter_argument.sh` | 153 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_parameter_argument.sh` | 156 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_parameter_argument.sh` | 171 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_parameter_argument.sh` | 246 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_registry_differential.sh` | 125 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_registry_differential.sh` | 131 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_registry_differential.sh` | 159 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_registry_differential.sh` | 226 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_scalar_expression.sh` | 94 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_scalar_expression.sh` | 101 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_scalar_expression.sh` | 125 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_scalar_expression.sh` | 201 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_scalar_expression.sh` | 256 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_source_metadata.sh` | 96 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase13_source_metadata.sh` | 97 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase13_source_metadata.sh` | 106 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase14_composition_differential.sh` | 128 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase14_composition_differential.sh` | 134 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase14_composition_differential.sh` | 162 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase15_move_state_parity.sh` | 288 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase15_resource_composition_parity.sh` | 13 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase15_resource_composition_parity.sh` | 14 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase16_abi_composition_parity.sh` | 12 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase16_abi_composition_parity.sh` | 13 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase19_classification_parity.sh` | 23 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_composition_parity.sh` | 20 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_composition_parity.sh` | 21 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase19_composition_parity.sh` | 54 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase19_gust_name_list_removed_parity.sh` | 32 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_rename_invariance.sh` | 50 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_representation_parity.sh` | 32 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_rule_convergence_parity.sh` | 25 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase19_type_naming_parity.sh` | 34 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_arena_free.sh` | 34 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_arena_free.sh` | 35 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_arena_free.sh` | 57 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_arena_free.sh` | 59 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_arena_free.sh` | 61 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_arena_free.sh` | 104 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_contextual_generic_constructor.sh` | 18 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_contextual_generic_constructor.sh` | 19 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_contextual_generic_constructor.sh` | 47 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_contextual_generic_constructor.sh` | 81 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_exact_brand_boundary.sh` | 22 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_exact_brand_boundary.sh` | 23 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_exact_brand_boundary.sh` | 42 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_exact_brand_boundary.sh` | 86 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_exact_brand_boundary.sh` | 102 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generated_mir_scale.py` | 507 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generated_mir_scale.py` | 525 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generated_mir_scale.py` | 616 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generated_mir_scale.py` | 627 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generic_guard_prerequisites.sh` | 17 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_generic_guard_prerequisites.sh` | 33 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_inert_resource_surface.sh` | 14 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_inert_resource_surface.sh` | 16 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_inert_resource_surface.sh` | 19 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_nested_brand_annotation.sh` | 15 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_nested_brand_annotation.sh` | 16 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_nested_brand_annotation.sh` | 32 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_nested_brand_annotation.sh` | 40 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_nested_brand_annotation.sh` | 85 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_nested_brand_annotation.sh` | 101 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_protected_access_liveness.sh` | 14 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_protected_access_liveness.sh` | 15 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_protected_access_liveness.sh` | 41 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_acquisition.sh` | 32 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_acquisition.sh` | 34 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_acquisition.sh` | 62 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_acquisition.sh` | 64 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_acquisition.sh` | 67 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_acquisition.sh` | 85 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_acquisition.sh` | 103 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_declaration_migration.sh` | 20 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_declaration_migration.sh` | 22 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_enforcement.sh` | 45 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_enforcement.sh` | 46 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_enforcement.sh` | 67 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_enforcement.sh` | 69 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_enforcement.sh` | 72 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_enforcement.sh` | 97 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_scope_cleanup.sh` | 11 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase20_resource_scope_cleanup.sh` | 12 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_scope_cleanup.sh` | 25 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_scope_cleanup.sh` | 31 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_scope_cleanup.sh` | 36 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_resource_scope_cleanup.sh` | 47 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_stdlib_runtime_differential.sh` | 29 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_stdlib_runtime_differential.sh` | 34 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_whole_program_corpus.sh` | 43 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_whole_program_corpus.sh` | 72 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_whole_program_corpus.sh` | 128 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase20_whole_program_corpus.sh` | 131 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_collection_string_native_source.sh` | 97 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase21_collection_string_native_source.sh` | 99 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_collection_string_native_source.sh` | 110 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_collection_string_native_source.sh` | 161 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase21_collection_string_native_source.sh` | 163 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_collection_string_native_source.sh` | 182 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_collection_string_native_source.sh` | 210 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_compiler_support_native_qualification.py` | 360 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_compiler_support_native_qualification.py` | 394 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_complete_guard_suite.py` | 603 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cranelift_built_compiler_programs.py` | 304 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cranelift_built_compiler_programs.py` | 337 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cranelift_built_compiler_programs.py` | 362 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cranelift_built_compiler_programs.py` | 422 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cross_tenant_capability.sh` | 15 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cross_tenant_capability.sh` | 25 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cross_tenant_capability.sh` | 51 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_cross_tenant_capability.sh` | 56 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 205 | `none` | `implicit_default` | `cranelift_C_or_diagnostic_guard` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_changes_the_guard_artifact_before_explicit_C_migration` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 207 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 217 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 275 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 295 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_filesystem_allocation_native_source.sh` | 323 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_full_compiler_native_qualification.py` | 359 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_full_compiler_native_qualification.py` | 384 | `none` | `implicit_default` | `help_surface_probe` | `cranelift` | `22.6_flip_help_expectation` | `help_expectation_changes_before_the_default_route` |
| `scripts/phase21_inert_scoped_query_records.sh` | 28 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_od8_adversarial_verdict.sh` | 15 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_od8_adversarial_verdict.sh` | 43 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_od8_adversarial_verdict.sh` | 71 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_od8_adversarial_verdict.sh` | 76 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 20 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 27 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 64 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 68 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 99 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_opening.sh` | 106 | `none` | `implicit_default` | `help_surface_probe` | `cranelift` | `22.6_flip_help_expectation` | `help_expectation_changes_before_the_default_route` |
| `scripts/phase21_opening.sh` | 116 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_per_root_obligations.sh` | 15 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_per_root_obligations.sh` | 33 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_per_root_obligations.sh` | 56 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_per_root_obligations.sh` | 61 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_resource_sync_native_source.sh` | 96 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_resource_sync_native_source.sh` | 101 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_resource_sync_native_source.sh` | 129 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_resource_sync_native_source.sh` | 139 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_resource_sync_native_source.sh` | 153 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_selected_compiler_module_qualification.py` | 441 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_selected_compiler_module_qualification.py` | 492 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_selected_compiler_module_qualification.py` | 556 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_selected_compiler_module_qualification.py` | 585 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_trusted_scope_provenance.sh` | 14 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_trusted_scope_provenance.sh` | 24 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_trusted_scope_provenance.sh` | 49 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_trusted_scope_provenance.sh` | 54 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_trusted_scope_provenance.sh` | 72 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_typed_query_noop_surface.sh` | 16 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_typed_query_noop_surface.sh` | 41 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase21_typed_query_noop_surface.sh` | 47 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase22_opening.sh` | 25 | `none` | `implicit_default` | `intentional_default_selection_probe` | `cranelift` | `22.6_flip_expectation_only` | `probe_is_migrated_before_the_default_route_changes` |
| `scripts/phase22_opening.sh` | 26 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase22_opening.sh` | 34 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase22_opening.sh` | 43 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/phase22_opening.sh` | 52 | `none` | `implicit_default` | `intentional_default_selection_probe` | `cranelift` | `22.6_flip_expectation_only` | `probe_is_migrated_before_the_default_route_changes` |
| `scripts/phase22_opening.sh` | 63 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `cranelift` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/run-gust-file.sh` | 35 | `none` | `implicit_default` | `developer_generated_C_pipeline` | `cranelift` | `22.2_explicit_C_selection` | `default_flip_sends_generated_C_pipeline_to_native_output` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 60 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 62 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 64 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 66 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 130 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 157 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 63 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 65 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 67 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 69 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 128 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 152 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_composition_parity.sh` | 30 | `none` | `implicit_default` | `stdlib_owned_C_or_diagnostic_guard` | `stdlib` | `checked_cross_lane_relay_before_22.6` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_composition_parity.sh` | 31 | `none` | `explicit_c` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |
| `scripts/stdlib_s1_composition_parity.sh` | 72 | `none` | `explicit_cranelift` | `already_explicit_or_parser_probe` | `stdlib` | `preserve_explicit_selection` | `explicit_selection_is_removed_or_routes_to_a_different_backend` |

## Phase 21 native-capability handoff

- Complete inventory: `326`
- Required native cases: `192`
- Compile deferrals: `121`
- Oracle precondition failures: `10`
- Runtime divergences: `3`
- Default policy: `unsupported_native_features_fail_clearly_without_C_fallback`
- Cleanup destination: `22.5_pre_flip_default_cohort_qualification`

## Stability qualification

- Operator decision: `2026-08-29_one_time_exact_final_main`
- Required successful runs: `1`
- Workflow: `Cranelift Historical Full`
- Required head: `exact_merged_final_post_flip_implementation_main`
- Required job population: `complete_registry_derived_population_all_success`
- Maximum unresolved material review findings: `0`

Patch 22.1 changes no route. The invocation inventory is a transition
checklist: Patch 22.2 makes C-dependent consumers explicit while bare
Gust still emits C; later patches own omitted native output, packaging,
the default flip, seed reconvergence, and stability evidence.
