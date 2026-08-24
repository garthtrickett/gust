# Cranelift Phase 20 Long-Lived and Concurrent Resources

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_long_lived_concurrent.py project`. Do not edit by hand.

- Contract: `phase20_long_lived_concurrent_v1`
- Status: `patch20_15_complete`
- Next patch: `20.16`
- Normalization: `none`
- OD-13: `open_and_unchanged_not_part_of_patch20_15`

## Selected profiles

| Profile | Level | Concurrent cycles | Resource process runs |
| --- | ---: | ---: | ---: |
| `small` | 2 | 8 | 1 |
| `full` | 3 | 128 | 4 |

## Observable contract

- Resource lifecycle: sixteen_in_process_cycles_each_destroy_nested_fields_in_reverse_order_transfer_one_manual_terminal_owner_and_destroy_the_outer_owner_exactly_once
- Concurrency: two_pthreads_share_one_runtime_mutex_and_one_bounded_channel_producer_is_joined_after_deterministic_receive_count_and_sum_invariants
- Allocation: one_mutex_and_one_channel_are_reused_for_the_bounded_process_lifetime_and_reclaimed_with_the_test_process
- Backend route: MIR_to_C_source_and_direct_canonical_MIR_Cranelift_call_the_same_test_only_probe_and_link_the_same_production_runtime_without_fallback

The production runtime is unchanged. A test-only imported probe runs
real Mutex lock/unlock and bounded Channel send/receive operations.
MIR-to-C source and direct canonical-MIR Cranelift executions must have
the same exit status and exact stdout/stderr. The resource oracle runs
real source-declared cleanup and composes the existing shared compiler
cleanup-plan parity through its separately registered Level 2 owner;
direct source routes remain explicit exclusions.

## Explicit exclusions

- `direct_resource_source_to_cranelift` — `source_or_type_failure`; owner `phase13_generic_source_to_mir`; destination `20.16`; falsifier: the_direct_resource_source_route_compiles_and_executes_the_same_exact_cleanup_observables_with_MIR_to_C_poisoned
- `direct_threading_source_to_cranelift` — `deferred_p13_parameter_argument_target_dependent_abi`; owner `phase13_generic_source_to_mir`; destination `20.16`; falsifier: a_function_pointer_Mutex_or_Channel_source_program_compiles_and_executes_its_deterministic_invariant_with_MIR_to_C_poisoned
