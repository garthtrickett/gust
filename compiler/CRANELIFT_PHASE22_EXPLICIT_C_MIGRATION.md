# Cranelift Phase 22.2 — Explicit C Route and No-op Consumer Migration

Generated from `scripts/cranelift_feature_registry.json` and the live
repository invocation scan. Do not edit by hand.

- Contract: `phase22_explicit_c_migration_v2`
- Status: `cranelift_owned_migration_complete_relay_publication_authorized`
- Next action: `stdlib_owned_consumer_relay_publication`
- Observed main: `d7c0a733c211a202bda417fb7d5b8ceb12ced415`
- Default backend: `mir_to_c_unchanged`
- Explicit `c`: `exact_alias_of_mir_to_c`
- Cranelift-owned migrations: `60`
- Pre-relay implicit consumers: `26`
- Authorized post-relay implicit consumers: `11`
- Pre-relay explicit C consumers: `146`
- Authorized post-relay explicit C consumers: `161`
- Pre-relay implicit Stdlib-owned consumers: `15`
- Authorized post-relay implicit Stdlib-owned consumers: `0`
- Relay status: `authorized_for_owning_lane_publication`

## Migration classes

- Bootstrap/final compiler C generation: `5`
- Repository guards: `15`
- Script guards: `39`
- Developer C pipeline: `1`

## Pre-relay preserved implicit consumers

- `help_surface_probe`: `2`
- `intentional_default_selection_probe`: `7`
- `invocation_parser_probe`: `2`
- `stdlib_owned_C_or_diagnostic_guard`: `15`

## Authorized post-relay preserved implicit consumers

- `help_surface_probe`: `2`
- `intentional_default_selection_probe`: `7`
- `invocation_parser_probe`: `2`

## Cross-lane relay

| Path | Line | Recipe | Compiler |
| --- | ---: | --- | --- |
| `justfile` | 23146 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23147 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23161 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23193 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23197 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23204 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23205 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23287 | `guard-stdlib-s1-resource-prerequisites` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 60 | `none` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 64 | `none` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 130 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 63 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 67 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 128 | `none` | `./gust` |
| `scripts/stdlib_s1_composition_parity.sh` | 30 | `none` | `./gust` |

Patch 22.2 remains open. This authority accepts only the exact pre-relay
inventory or the exact checked 15-site post-relay inventory, allowing
the owning Stdlib correction to publish without treating partial or
unrelated invocation drift as completion. The default flip remains
forbidden until that owning PR actually merges. This authority patch
does not edit Stdlib or change the MIR-to-C default.
