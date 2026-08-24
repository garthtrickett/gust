# Cranelift Phase 20 Generated MIR and Scale Qualification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_generated_mir_scale.py project`. Do not edit by hand.

- Contract: `phase20_generated_mir_scale_v1`
- Status: `patch20_14_complete`
- Next patch: `20.14a`
- Generator: `scripts/phase20_generated_mir_scale.py`
- Algorithm: `lcg32_seeded_abstract_scalar_plan_v1`
- Canonical MIR constraint: `validated_i32_scalar_local_operations_and_acyclic_local_calls_only`
- Route policy: `generated_scalars_and_large_function_use_three_way_source_and_direct_mir_agreement_while_large_module_uses_mir_to_c_source_oracle_against_direct_canonical_mir_because_the_source_native_planner_intentionally_rejects_unregistered_call_graph_shapes`
- Normalization: `none`

## Recorded cohorts

- `small_generated_scalar` — Level 2; operations `8`; seeds `level2`
- `full_generated_scalar` — Level 3; operations `24`; seeds `level3`
- `large_function` — Level 3; operations `1024`
- `large_module` — Level 3; functions `64`

## Reproducible resource protocol

- Protocol: `fresh_child_process_monotonic_elapsed_and_wait4_maxrss`
- Warmups: `1`
- Samples: `3`
- Elapsed statistic: `median`
- Memory statistic: `maximum`
- Threshold policy: `fixed_registry_values_reviewed_with_the_patch_no_runtime_rebasing`

| Cohort | Backend | Baseline ms | Baseline KiB | Maximum ms | Maximum KiB |
| --- | --- | ---: | ---: | ---: | ---: |
| `large_function` | `mir-to-c` | 24 | 16128 | 10000 | 262144 |
| `large_function` | `cranelift` | 107 | 83328 | 10000 | 262144 |
| `large_module` | `mir-to-c` | 8 | 16000 | 10000 | 262144 |
| `large_module` | `cranelift` | 16 | 16128 | 10000 | 262144 |

## Failure preservation

- Policy: any divergence is copied to the guard output, minimized to the shortest reproducing operation plan, and committed under compiler/fixtures/phase20_generated_failures before qualification may pass
- Committed minimized failures: `0`

Every generated scalar plan emits both Gust source and canonical MIR.
The source executes through MIR-to-C and explicit no-fallback Cranelift;
the canonical MIR executes through the generic ingestion worker. Exact
exit status, stdout, and stderr must agree across all three executions.
Level 3 alone owns exhaustive seeds, scale cohorts, and resource budgets.
