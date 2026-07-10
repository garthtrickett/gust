# Cranelift Phase 9C Differential Ledger

PHASE9C_DIFFERENTIAL_LEDGER_VERSION: 1
PHASE9C_DIFFERENTIAL_LEDGER_STATUS: phase9c_initial_seven_lane_baseline
PHASE9C_DIFFERENTIAL_LEDGER_LANE_COUNT: 7
PHASE9C_DIFFERENTIAL_LEDGER_ORACLE_ROUTE: mir_to_c
PHASE9C_DIFFERENTIAL_LEDGER_CANDIDATE_ROUTE: mir_to_cranelift_experiment_only
PHASE9C_DIFFERENTIAL_LEDGER_ROUTE_POLICY: experiment_only_no_default_backend_flip
PHASE9C_DIFFERENTIAL_LEDGER_RESULT_POLICY: each_lane_records_oracle_candidate_expected_status_and_divergence_owner
PHASE9C_DIFFERENTIAL_LEDGER_FUTURE_LANE_POLICY: prefer_compiler_owned_mir_ingestion_before_new_bespoke_translator_lanes

This ledger freezes the Phase 9C initial comparison set. It is deliberately an audit surface, not a backend route flip. MIR-to-C remains the oracle. Cranelift remains an experiment-only candidate until later phases replace fixture-shaped candidates with compiler-owned MIR ingestion and shared lowering.

## Lanes

### return_int_literal

lane: return_int_literal
oracle_guard: guard-mir-to-c-return-int-literal-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke
expected_native_status: 1
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
promotion_blocker: candidate_still_experiment_only_fixture_translator

### local_binding_read

lane: local_binding_read
oracle_guard: guard-mir-to-c-local-binding-read-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke
expected_native_status: 2
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
promotion_blocker: candidate_still_experiment_only_fixture_translator

### conditional_branch

lane: conditional_branch
oracle_guard: guard-mir-to-c-conditional-branch-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke
expected_native_status: 1
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
promotion_blocker: candidate_still_experiment_only_fixture_translator

### block_jump

lane: block_jump
oracle_guard: guard-mir-to-c-block-jump-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke
expected_native_status: 1
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
promotion_blocker: candidate_still_experiment_only_fixture_translator

### provenance_metadata

lane: provenance_metadata
oracle_guard: guard-mir-to-c-provenance-metadata-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke
expected_native_status: 2
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
semantic_scope: metadata_preservation_recognition_without_claiming_full_resource_semantics
promotion_blocker: candidate_still_experiment_only_fixture_translator

### resource_metadata

lane: resource_metadata
oracle_guard: guard-mir-to-c-resource-metadata-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke
expected_native_status: 2
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
semantic_scope: metadata_preservation_recognition_without_claiming_full_resource_semantics
promotion_blocker: candidate_still_experiment_only_fixture_translator

### native_boundary_metadata

lane: native_boundary_metadata
oracle_guard: guard-mir-to-c-native-boundary-metadata-native-smoke
candidate_guard: guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke
expected_native_status: 0
current_result: registered_initial_ladder
failure_owner_policy: oracle_candidate_or_divergence_must_be_identified
candidate_shape: phase9b_translator_seed
semantic_scope: metadata_preservation_recognition_without_claiming_full_runtime_boundary_lowering
promotion_blocker: candidate_still_experiment_only_fixture_translator

## Next ingestion policy

New Phase 9C+ lanes should prefer compiler-owned MIR ingestion over new bespoke translator seeds. A lane may stay in this ledger only if it remains experiment-only, records its MIR-to-C oracle guard, records its Cranelift candidate guard, records its expected native status, and keeps production routing unchanged.
