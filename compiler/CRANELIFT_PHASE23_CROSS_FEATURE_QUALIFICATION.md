# Cranelift Phase 23.13 — Cross-Feature Qualification

Generated from `scripts/cranelift_feature_registry.json`; do not edit by hand.

- Contract: `phase23_cross_feature_qualification_v1`
- Status: `patch23_13_complete`
- Next patch: `23.14`
- Phase 23 Level 1 guards: `12`
- Phase 23 Level 2 guards: `8`
- Supplemental Level 2 owners: `5`
- Unexplained differences: `0`
- Module or fixture exceptions: `0`
- Unclassified residues: `0`

## Execution model

The aggregate builds the native package once, then executes every
registered guard command unchanged with the runner's existing
`GUST_RUNNER_SKIP_BUILD=1` mode. The final `make bootstrap` runs
without that environment override. This removes redundant compiler
rebuilds without changing the guard population or the 85-minute budget.

## Coverage

- `level1_authority`: `phase23_level1_guards`
- `level2_behaviour`: `phase23_level2_guards`
- `issue_health`: `phase23_mir_evidence_owner, phase23_resource_acquisition_parity, phase23_same_scope_declaration`
- `assurance_report_only`: `phase23_assurance_phase_a, phase23_assurance_phase_b`
- `deprecation_and_frozen_surface`: `phase23_mir_to_c_deprecation_opening, phase23_mir_to_c_frozen_surface`
- `focused_live_and_archive`: `phase23_mir_to_c_focused_live, phase23_mir_to_c_archived_corpus`
- `package_install_and_release`: `phase23_production_release_audit, guard-cranelift-phase22-postflip-qualification-evidence`
- `bootstrap`: `make bootstrap, guard-cranelift-phase22-default-route-seed-convergence`
- `default_and_explicit_native`: `guard-cranelift-phase22-postflip-qualification-evidence`
- `explicit_c_identity`: `guard-cranelift-phase23-mir-to-c-deprecation-opening-evidence, guard-cranelift-phase23-mir-to-c-focused-live-evidence`
- `cleanup_and_resources`: `guard-cranelift-phase20-resource-scope-cleanup-parity, guard-cranelift-phase23-resource-acquisition-parity-contract`
- `side_effects`: `guard-cranelift-phase23-mir-to-c-focused-live-evidence, guard-cranelift-phase23-production-release-audit-evidence`
- `diagnostics`: `guard-cranelift-phase23-same-scope-declaration-evidence, guard-cranelift-phase18-target-diagnostic-parity`
- `target`: `guard-cranelift-phase18-target-authority-parity, guard-cranelift-phase18-target-support-parity, guard-cranelift-phase18-target-diagnostic-parity`
- `no_fallback`: `guard-cranelift-phase22-postflip-qualification-evidence, guard-cranelift-phase23-production-release-audit-evidence`
- `consumer_scanner`: `phase23_mir_to_c_deprecation_opening.inventory_summary`
- `workflow_reachability`: `scripts/guard_reachability.py, scripts/fixture_reachability.py`

## Residues

- `nonbootstrap_explicit_c_evidence`: `173` calls; owner `cranelift`; destination Phase `24`.
  - Reason: `deprecated_generated_C_backend_retained_for_the_single_focused_oracle_and_classified_historical_or_archived_evidence`.
  - Falsifier: `count_or_complete_identity_changes_or_any_supported_production_or_release_route_requires_C`.
- `bootstrap_explicit_c_chain`: `5` calls; owner `cranelift`; destination Phase `25`.
  - Reason: `make_gust_make_bootstrap_and_the_committed_C_seed_remain_owned_by_the_separate_bootstrap_retirement_phase`.
  - Falsifier: `count_or_identity_changes_or_bootstrap_stops_using_the_registered_explicit_C_chain_before_Phase_25`.

## Route inventory

- Repository invocations: `318`
- Explicit C: `178`
- Phase 25 bootstrap explicit C: `5`
- Non-bootstrap retained C: `173`
- Supported production/release C requirements: `0`
- Unknown downstream consumers: `0`

Issues #105, #110, and #240 are closed on their registered merged
current-main evidence. Assurance A/B remains report-only. The two
residue rows partition every explicit-C invocation and preserve the
separate Phase 24 generated-C and Phase 25 bootstrap-C boundaries.
This qualification introduces no module, fixture, source-spelling, or
stdlib exception and changes no semantics, MIR, ABI, runtime symbol,
route, fallback, target, linker, bootstrap seed, Stdlib, or CR-15 state.
