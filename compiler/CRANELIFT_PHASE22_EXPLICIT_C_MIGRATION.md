# Cranelift Phase 22.2 — Explicit C Route and No-op Consumer Migration

Generated from `scripts/cranelift_feature_registry.json` and the live
repository invocation scan. Do not edit by hand.

- Contract: `phase22_explicit_c_migration_v2`
- Status: `complete_post_relay`
- Next action: `patch22_6_default_route_flip`
- Observed main: `d7c0a733c211a202bda417fb7d5b8ceb12ced415`
- Default backend: `mir_to_c_unchanged`
- Explicit `c`: `exact_alias_of_mir_to_c`
- Cranelift-owned migrations: `60`
- Pre-relay implicit consumers: `26`
- Merged post-relay implicit consumers: `11`
- Pre-relay explicit C consumers: `146`
- Merged post-relay explicit C consumers: `161`
- Pre-relay implicit Stdlib-owned consumers: `15`
- Merged post-relay implicit Stdlib-owned consumers: `0`
- Relay status: `merged_on_main`
- Relay PR: `#256` at `884cb57aee466da24410ade1a9bc7ddc9e592dd7`
- Relay merged main: `8045704ca5632e3ad096d1cd25eac12c57a4b28b`
- Relay PR workflows: `73` successful
- Relay unresolved review threads: `0`

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

## Merged post-relay preserved implicit consumers

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

## Post-flip review relay

- Status: `transition_authorized_awaiting_owning_stdlib_merge`
- Review: `#251` / `PRRT_kwDOS1ExJc6dYPJO`
- Authorized owning PR: `#264` at `95144aea75dd3812cd52e86391ea5a8c54b11363`
- Landed merge evidence: `pending_owning_stdlib_merge`
- Required owning transitions: `6`
- Expected selection: `explicit_mir_to_c`
- `tests/e2e_codegen_assertions.gst:33`
- `tests/e2e_codegen_assertions.gst:39`
- `tests/e2e_codegen_assertions.gst:45`
- `tests/e2e_codegen_assertions.gst:52`
- `tests/test_runner.gst:119`
- `tests/test_runner.gst:154`

Patch 22.2's original relay is complete. The owning Stdlib relay merged with its complete
exact-head pull-request population successful and zero review threads.
This authority now accepts only the exact merged 15-site post-relay
inventory plus the six test-owned consumers discovered by post-merge
review. The transition authority admits only the exact pre-relay
manifest or the exact two-path/six-site post-relay manifest; partial,
extra-site, path-drift, same-count substitution, and unrelated inventory
states reject. Authorization is not landed merge evidence, and Patch
22.8 remains blocked until the owning merge is recorded. This correction
does not edit Stdlib.
