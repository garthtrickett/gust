# Cranelift Phase 23.14 — Exact-Main Historical Full Qualification

Generated from `scripts/cranelift_feature_registry.json`; do not edit by hand.

- Contract: `phase23_historical_full_qualification_v1`
- Status: `patch23_14_complete`
- Next patch: `23.15`
- Predecessor: `phase23_cross_feature_qualification_v1`

## Final implementation and review gate

- PR/head: `#296` / `321ddd2e0cb093298db800a7ea966d5ae92e5418`
- Exact merged main: `fee6600d86f85f8a0a0da94211ae89895869187e`
- Exact-head workflows: `123/123` successful
- Unfinished/non-success: `0/0`
- Unresolved review threads/material findings: `0/0`

## Authoritative Historical Full

- Workflow/run: `Cranelift Historical Full` / `33584176425`
- Event/branch: `workflow_dispatch` / `main`
- Exact head: `fee6600d86f85f8a0a0da94211ae89895869187e`
- Status/conclusion: `completed` / `success`
- Complete jobs: `18/18` successful
- Unfinished/non-success: `0/0`
- Created/completed: `2026-09-02T02:41:49Z` / `2026-09-02T04:12:03Z`

## Population and budgets

- Historical shards: `10`
- Registry-derived declared targets: `5`
- Expected/observed unique jobs: `18/18`
- Every expected job exactly once: `true`
- Per-job timeout: `10800` seconds
- Observed run/max/aggregate seconds: `5414/4286/22697`
- Every job within budget: `true`

## Registered coverage

- final_implementation: `phase23_cross_feature_qualification_v1`
- issue_health: `phase23_mir_evidence_owner_v1, phase23_resource_acquisition_parity_v1, phase23_same_scope_declaration_v1`
- assurance_report_only: `phase23_assurance_phase_a_v1, phase23_assurance_phase_b_v1`
- focused_compatibility_successor: `phase23_mir_to_c_focused_live_v1`
- native_default_package_no_fallback: `phase23_production_release_audit_v1`
- bootstrap_fixed_point: `phase23_cross_feature_qualification_v1`
- historical_population: `.github/workflows/cranelift-historical-full.yml`

Only a change that alters the Historical workload or final
implementation artifact invalidates this run. This generated
authority projection does not stale its recorded implementation main.

This authority records the exact final implementation main and its
complete Historical population. It changes no program meaning, MIR
operation, ABI, runtime symbol, backend route, fallback, bootstrap
seed, Stdlib surface, or CR-15 state, and it does not begin Patch 23.15.
