# Cranelift Phase 20 Whole-Program Corpus

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_whole_program_corpus.py project`. Do not edit by hand.

- Contract: `phase20_whole_program_corpus_v1`
- Status: `patch20_12_complete`
- Next patch: `20.13`
- Harness: `scripts/phase20_whole_program_corpus.sh`
- Canonical MIR policy: `one_registry_case_owns_one_source_route_and_successful_cranelift_compilation_must_publish_and_consume_its_captured_compiler_owned_canonical_mir_bundle`
- No-fallback policy: `explicit_cranelift_runs_with_mir_to_c_poisoned_and_must_not_fall_back`
- Normalization policy: `none_in_the_initial_cohort`

## Observables

- `compile_result` — `exact_integer_status`
- `process_exit_status` — `exact_integer_status_for_successful_compilation`
- `stdout` — `exact_bytes`
- `stderr_diagnostics` — `exact_bytes_and_required_semantic_code`
- `resource_terminal_state` — `registry_declared_terminal_state_for_each_case`
- `sandboxed_filesystem_effects` — `exact_relative_tree_kind_and_bytes`

## Selected initial cohort

- `p20_multi_module_runtime_scalar` — `runtime_success`, exit 49; features `modules,direct_calls,runtime_import`
- `p20_structured_control_flow` — `runtime_success`, exit 14; features `control_flow,nested_branches,locals`
- `p20_local_call_and_assignment` — `runtime_success`, exit 15; features `direct_calls,assignments,locals`
- `p20_generic_brand_aggregate_rejection` — `compile_failure`, compile 1 / `TypeMismatch`; features `generics,brands,aggregates,failure_diagnostics`
- `p20_resource_path_rejection` — `compile_failure`, compile 1 / `ResourceAcquisitionLeak`; features `resources,control_flow,failure_diagnostics`

## Explicit exclusions

- `successful_generic_brand_resource_source_route` — owner `phase13_generic_source_to_mir`; next `20.13`
  - Reason: successful generic branded Resource programs remain explicit pre-driver source-route rejections and cannot be counted as native whole-program parity
  - Falsifier: the direct source route compiles a representative generic branded Resource program with MIR-to-C poisoned and its full observable differential passes
- `observable_runtime_io_and_filesystem` — owner `phase17_io_runtime_authority`; next `20.13`
  - Reason: the initial connected source cohort has no selected runtime I/O or filesystem helper route
  - Falsifier: a registry-selected runtime component case produces matching nonempty I/O or filesystem effects through both backends
- `costly_whole_program_cases` — owner `phase20_generated_mir_and_scale`; next `20.14`
  - Reason: the deterministic initial cohort is bounded and has no case whose measured cost warrants Level 3
  - Falsifier: a selected whole-program case exceeds the Level 2 cost policy and is registered in Cranelift Historical Full

The initial cohort claims only connected runtime programs and exact
shared-front-end failures. Successful generic, branded, Resource, and
observable I/O/filesystem programs are not silently counted as native
parity; their exclusions remain registered until their stated falsifiers
are met. No selected case permits environmental normalization.
