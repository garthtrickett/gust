# Cranelift Phase 18 Opening Inventory

- Opening version: `phase18_opening_inventory_rebased_on_phase17_closure`
- Inventory version: `phase18_opening_inventory_v1`
- Status: `ready_for_patch18_1`
- Predecessor closure: `phase17_closed_native_runtime_boundary`
- Opening rows: `17`
- Host assumptions: `9`
- Candidate targets: `5`
- Inherited residuals rebased: `24`
- Projected CI families: `17`

## Opening rows

| ID | Feature family | CI family | Capability owner | Status |
| --- | --- | --- | --- | --- |
| `p18_target_authority` | target_identity | target-identity | compiler_target_authority_planner | candidate_deferred |
| `p18_target_support_tuple` | target_support | target-support-tuple | compiler_target_support_planner | candidate_deferred |
| `p18_object_format` | object_format | object-format | compiler_object_format_planner | candidate_deferred |
| `p18_relocation_model` | relocation | relocations | compiler_relocation_planner | candidate_deferred |
| `p18_target_abi_selection` | target_abi | target-abi-selection | compiler_target_abi_selection_planner | candidate_deferred |
| `p18_target_runtime_package_selection` | target_runtime_package | target-runtime-packages | compiler_target_package_selection_planner | candidate_deferred |
| `p18_linker_policy` | linker | linker-policy | compiler_linker_policy_planner | candidate_deferred |
| `p18_link_modes` | link_mode | link-modes | compiler_link_mode_planner | candidate_deferred |
| `p18_cross_compilation` | cross_compilation | cross-compilation | compiler_cross_compilation_planner | candidate_deferred |
| `p18_target_diagnostics` | target_diagnostic | target-diagnostics | compiler_target_diagnostic_planner | candidate_deferred |
| `p18_object_inspection` | object_inspection | object-inspection | compiler_object_inspection_planner | candidate_deferred |
| `p18_debug_information` | debug_information | debug-info | compiler_debug_information_planner | candidate_deferred |
| `p18_source_locations` | source_location | source-locations | compiler_source_location_planner | candidate_deferred |
| `p18_optimisation_levels` | optimisation_level | optimisation-levels | compiler_optimisation_level_planner | candidate_deferred |
| `p18_reproducible_output` | reproducibility | reproducibility | compiler_reproducibility_planner | candidate_deferred |
| `p18_atomic_publication` | publication | publication | compiler_publication_planner | candidate_deferred |
| `p18_complete_target_evidence` | target_evidence | target-evidence | compiler_target_evidence_planner | candidate_deferred |

## Host assumptions

| ID | Reachability area | Owning row | Source |
| --- | --- | --- | --- |
| `p18_host_native_target_triple` | target_selection | `p18_target_authority` | `src/runtime/file_io.c` |
| `p18_host_native_object_format` | target_selection | `p18_object_format` | `src/runtime/file_io.c` |
| `p18_host_cranelift_native_isa` | cranelift_lowering | `p18_target_authority` | `compiler/experiments/cranelift/src/main.rs` |
| `p18_host_object_builder_isa` | object_emission | `p18_object_format` | `compiler/experiments/cranelift/src/main.rs` |
| `p18_host_relocation_defaults` | object_emission | `p18_relocation_model` | `compiler/experiments/cranelift/src/main.rs` |
| `p18_host_runtime_package_target` | runtime_package_selection | `p18_target_runtime_package_selection` | `scripts/cranelift_feature_registry.json` |
| `p18_host_linker_driver_env` | link_planning | `p18_linker_policy` | `compiler/experiments/cranelift/src/main.rs` |
| `p18_host_linker_invocation` | link_planning | `p18_linker_policy` | `compiler/experiments/cranelift/src/main.rs` |
| `p18_host_publication_rename` | publication | `p18_atomic_publication` | `compiler/experiments/cranelift/src/main.rs` |

## Candidate targets

Every candidate is unsupported until its complete compiler, runtime, linker, and ABI tuple is proven.

| Target | Support decision | Missing tuple elements |
| --- | --- | --- |
| `x86_64-unknown-linux-gnu` | unsupported_pending_tuple_evidence | compiler, runtime_package, linker, abi |
| `aarch64-unknown-linux-gnu` | unsupported_pending_tuple_evidence | compiler, runtime_package, linker, abi |
| `i686-unknown-linux-gnu` | unsupported_pending_tuple_evidence | compiler, runtime_package, linker, abi |
| `x86_64-apple-darwin` | unsupported_pending_tuple_evidence | compiler, runtime_package, linker, abi |
| `aarch64-apple-darwin` | unsupported_pending_tuple_evidence | compiler, runtime_package, linker, abi |

## Inherited residual rebase

| Source residual | Origin | Disposition | Selected rows | Destination |
| --- | --- | --- | --- | --- |
| `p17_complete_sysv_aggregate_abi` | phase16 | split | `p18_target_abi_selection` | phase19 |
| `p17_complete_aarch64_pcs` | phase16 | split | `p18_target_abi_selection` | phase19 |
| `p17_dynamic_library_symbol_version_abi` | phase16 | split | `p18_link_modes` | phase19 |
| `p17_variadic_gust_calls` | phase16 | reassigned | — | phase19 |
| `p17_c_variadic_calls` | phase16 | reassigned | — | phase19 |
| `p17_target_homogeneous_aggregate_abi` | phase16 | reassigned | — | phase19 |
| `p17_vector_simd_calling_convention` | phase16 | reassigned | — | phase19 |
| `p17_complete_windows_aggregate_abi` | phase16 | reassigned | — | phase19 |
| `p17_signature_erased_function_pointers` | phase16 | reassigned | — | phase19 |
| `p17_arbitrary_unsized_aggregate_fields` | phase16 | reassigned | — | phase19 |
| `p17_unbounded_dynamic_stack_and_probing` | phase16 | reassigned | — | phase19 |
| `p17_foreign_aggregate_parameters_returns` | phase16 | reassigned | — | phase19 |
| `p17_foreign_resource_ownership_transfer` | phase16 | reassigned | — | phase19 |
| `p17_cross_version_module_abi` | phase16 | reassigned | — | phase19 |
| `p17_tail_call_abi` | phase16 | reassigned | — | phase19 |
| `p17_unwind_exception_personality_abi` | phase16 | reassigned | — | phase19 |
| `p18_subprocess_execution` | phase17 | reassigned | — | phase19 |
| `p18_cooperative_fiber_scheduling` | phase17 | reassigned | — | phase19 |
| `p18_work_distribution_scheduler` | phase17 | reassigned | — | phase19 |
| `p18_fiber_unwind_and_cancellation_cleanup` | phase17 | reassigned | — | phase19 |
| `p18_pure_gust_collections_and_strings` | phase17 | reassigned | — | phase19 |
| `p18_allocator_domains_and_root_allocation` | phase17 | reassigned | — | phase19 |
| `p18_async_io_and_file_handle_resources` | phase17 | reassigned | — | phase19 |
| `p18_fiber_component_retirement` | phase17 | reassigned | — | phase19 |
