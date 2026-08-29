# Cranelift Phase 22.2 — Explicit C Route and No-op Consumer Migration

Generated from `scripts/cranelift_feature_registry.json` and the live
repository invocation scan. Do not edit by hand.

- Contract: `phase22_explicit_c_migration_v1`
- Status: `cranelift_owned_migration_complete_cross_lane_pending`
- Next action: `stdlib_owned_consumer_relay`
- Observed main: `831a125263961943e81dc4888c3f83458325af4f`
- Default backend: `mir_to_c_unchanged`
- Explicit `c`: `exact_alias_of_mir_to_c`
- Cranelift-owned migrations: `60`
- Remaining implicit consumers: `26`
- Pending Stdlib-owned consumers: `15`

## Migration classes

- Bootstrap/final compiler C generation: `5`
- Repository guards: `15`
- Script guards: `39`
- Developer C pipeline: `1`

## Preserved implicit consumers

- `help_surface_probe`: `2`
- `intentional_default_selection_probe`: `7`
- `invocation_parser_probe`: `2`
- `stdlib_owned_C_or_diagnostic_guard`: `15`

## Cross-lane relay

| Path | Line | Expected artifact | Falsifier |
| --- | ---: | --- | --- |
| `justfile` | 23146 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23147 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23161 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23193 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23197 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23204 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23205 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `justfile` | 23287 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 60 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 64 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 130 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 63 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 67 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 128 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |
| `scripts/stdlib_s1_composition_parity.sh` | 30 | `generated_C_or_diagnostic` | `default_flip_lands_before_the_owning_lane_classifies_the_consumer` |

Patch 22.2 remains open: the Cranelift-owned no-op migration is
complete, but the roadmap exit gate forbids DONE status or a later
default flip until these owning Stdlib corrections merge. This patch
does not edit Stdlib or change the MIR-to-C default.
