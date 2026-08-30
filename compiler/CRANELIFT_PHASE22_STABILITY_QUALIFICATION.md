# Cranelift Phase 22.8 — One-Time Stability Qualification

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_stability_qualification_v1`
- Status: `one_time_exact_main_qualification_complete`
- Next patch: `22.9`
- Predecessor: `phase22_historical_route_successor_v1`
- Operator policy: `2026-08-29_one_authoritative_exact_final_main_run`

## Authoritative Historical Full

- Workflow/run: `Cranelift Historical Full` / `33298850155`
- Event/branch: `workflow_dispatch` / `main`
- Exact head: `a7adbcd186512a3b4fd99b953bb2bc30f6838c52`
- Status/conclusion: `completed` / `success`
- Complete jobs: `18/18` successful
- Unfinished/non-success: `0/0`
- Created/completed: `2026-08-30T07:17:24Z` / `2026-08-30T08:34:02Z`

## Elapsed budgets

- Per-job timeout: `10800` seconds
- Observed run wall time: `4598` seconds
- Observed maximum job time: `3861` seconds
- Observed aggregate job time: `24422` seconds
- Every job within budget: `true`

## Review and retained gates

- Final relay PR/head: `#264` / `3ada756e209bfa0556895169870ae00f96d94022`
- Final relay review threads: `0`
- Corrected material finding: `#265` / `PRRT_kwDOS1ExJc6dfJGe`
- Correction: `exact_six_command_manifest_with_negative_substitution_guards`
- Unresolved material findings: `0`
- explicit_c_oracle_and_rollback: `qualified`
- package_and_install: `qualified`
- bootstrap_route: `explicit_mir_to_c`
- pull_request_ci: `exact_full_head_sha_required`
- fallback: `forbidden`

This is the operator-selected single exact-final-main qualification,
not a repeated daily soak. It records no Gust semantic, MIR/lowering,
ABI/layout/runtime-symbol, target/linker, default-route, fallback,
bootstrap/seed, Stdlib, or CR-15 change and does not begin Patch 22.9.
