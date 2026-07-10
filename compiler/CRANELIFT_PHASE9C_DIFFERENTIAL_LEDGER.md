# Cranelift Phase 9C Differential Ledger

PHASE9C_DIFFERENTIAL_LEDGER_VERSION: 1
PHASE9C_DIFFERENTIAL_LEDGER_STATUS: phase9c_seven_lane_ingestion_backed
PHASE9C_DIFFERENTIAL_LEDGER_LANE_COUNT: 7
PHASE9C_DIFFERENTIAL_LEDGER_ORACLE_ROUTE: mir_to_c
PHASE9C_DIFFERENTIAL_LEDGER_CANDIDATE_ROUTE: mir_to_cranelift_experiment_only
PHASE9C_DIFFERENTIAL_LEDGER_CANDIDATE_SHAPE: compiler_owned_mir_ingestion
PHASE9C_DIFFERENTIAL_LEDGER_INGESTION_CANDIDATE_COUNT: 7
PHASE9C_DIFFERENTIAL_LEDGER_TRANSLATOR_CANDIDATE_COUNT: 0
PHASE9C_DIFFERENTIAL_LEDGER_ROUTE_POLICY: experiment_only_no_default_backend_flip
PHASE9C_DIFFERENTIAL_LEDGER_RESULT_POLICY: each_lane_records_oracle_candidate_expected_status_and_divergence_owner
PHASE9C_DIFFERENTIAL_LEDGER_FUTURE_LANE_POLICY: prefer_compiler_owned_mir_ingestion_before_new_bespoke_translator_lanes

This ledger freezes the Phase 9C semantic comparison set. It is deliberately an audit surface, not a backend route flip. MIR-to-C remains the oracle and Cranelift remains experiment-only. All seven candidates now consume compiler-owned MIR fixtures, emit objects through the isolated Cranelift experiment, link with native shims, and validate their expected exit statuses. The frozen Phase 9B translator seeds remain historical experiment coverage, but they are no longer the Phase 9C differential candidates.

## Lanes

### return_int_literal

lane: return_int_literal
oracle_guard: guard-mir-to-c-return-int-literal-native-smoke
candidate_guard: guard-cranelift-compiler-mir-return-int-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_return_int_ingestion.mir
expected_native_status: 1
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### local_binding_read

lane: local_binding_read
oracle_guard: guard-mir-to-c-local-binding-read-native-smoke
candidate_guard: guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_local_binding_read_ingestion.mir
expected_native_status: 2
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### conditional_branch

lane: conditional_branch
oracle_guard: guard-mir-to-c-conditional-branch-native-smoke
candidate_guard: guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_conditional_branch_ingestion.mir
expected_native_status: 1
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### block_jump

lane: block_jump
oracle_guard: guard-mir-to-c-block-jump-native-smoke
candidate_guard: guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_block_jump_ingestion.mir
expected_native_status: 1
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### provenance_metadata

lane: provenance_metadata
oracle_guard: guard-mir-to-c-provenance-metadata-native-smoke
candidate_guard: guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_provenance_metadata_ingestion.mir
expected_native_status: 2
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
semantic_scope: metadata_preservation_recognition_without_claiming_full_resource_semantics
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### resource_metadata

lane: resource_metadata
oracle_guard: guard-mir-to-c-resource-metadata-native-smoke
candidate_guard: guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_resource_metadata_ingestion.mir
expected_native_status: 2
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
semantic_scope: metadata_preservation_recognition_without_claiming_full_resource_semantics
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

### native_boundary_metadata

lane: native_boundary_metadata
oracle_guard: guard-mir-to-c-native-boundary-metadata-native-smoke
candidate_guard: guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke
candidate_fixture: compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir
expected_native_status: 0
current_result: ingestion_backed_candidate_registered
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: compiler_owned_mir_ingestion
semantic_scope: metadata_preservation_recognition_without_claiming_full_runtime_boundary_lowering
promotion_blocker: ingestion_candidate_remains_experiment_only_no_production_route

## Phase 9C+ roadmap

All seven Phase 9C lanes now use the preferred compiler-owned MIR ingestion shape: compiler MIR fixture -> Cranelift ingestion -> object -> native result. New Phase 9C+ lanes should preserve this seam instead of adding bespoke translator seeds. A lane may stay in this ledger only if it remains experiment-only, records its MIR-to-C oracle guard, records its Cranelift candidate guard, records its expected native status, and keeps production routing unchanged.
