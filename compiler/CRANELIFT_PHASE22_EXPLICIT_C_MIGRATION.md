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
| `justfile` | 23068 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23069 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23083 | `guard-stdlib-s1-str-equality-diagnostic` | `./gust` |
| `justfile` | 23115 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23119 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23126 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23127 | `guard-stdlib-s1-collection-receivers` | `./gust` |
| `justfile` | 23209 | `guard-stdlib-s1-resource-prerequisites` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 60 | `none` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 64 | `none` | `./gust` |
| `scripts/stdlib_s1_branded_collections_parity.sh` | 130 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 63 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 67 | `none` | `./gust` |
| `scripts/stdlib_s1_clone_destination_parity.sh` | 128 | `none` | `./gust` |
| `scripts/stdlib_s1_composition_parity.sh` | 30 | `none` | `./gust` |

## Post-flip review relay

- Status: `landed_exact_post_relay_only`
- Review: `#251` / `PRRT_kwDOS1ExJc6dYPJO`
- Landed owning PR: `#264`
- Landed exact head: `3ada756e209bfa0556895169870ae00f96d94022`
- Landed merge main: `a7adbcd186512a3b4fd99b953bb2bc30f6838c52`
- Landed PR workflows: `6/6` successful
- Relayed review thread: `resolved_non_outdated`
- Required owning transitions: `6`
- Expected selection: `explicit_mir_to_c`
- `tests/e2e_codegen_assertions.gst:33` — `os.System("./gust --backend mir-to-c tests/codegen_helper_pod_move.gst > build/codegen_helper_pod_move_temp.log 2>&1");`
- `tests/e2e_codegen_assertions.gst:39` — `os.System("./gust --backend mir-to-c tests/codegen_helper_linear_move.gst > build/codegen_helper_linear_move_temp.log 2>&1");`
- `tests/e2e_codegen_assertions.gst:45` — `os.System("./gust --backend mir-to-c tests/codegen_helper_take_ops.gst > build/codegen_helper_take_ops_temp.log 2>&1");`
- `tests/e2e_codegen_assertions.gst:52` — `os.System("./gust --backend mir-to-c tests/codegen_helper_match_destructure.gst > build/codegen_helper_match_destructure_temp.log 2>&1");`
- `tests/test_runner.gst:119` — `mut cmd := std.Concat("./gust --backend mir-to-c ", path);`
- `tests/test_runner.gst:154` — `mut cmd_comp := std.Concat("./gust --backend mir-to-c ", path);`

Patch 22.2's original relay is complete. The owning Stdlib relay merged with its complete
exact-head pull-request population successful and zero review threads.
This authority now accepts only the exact merged 15-site post-relay
inventory plus the six test-owned consumers discovered by post-merge
review. The completed transition now admits only the exact landed
two-path/six-site post-relay manifest; the former pre-relay state,
partial, extra-site, path-drift, same-count substitution, and unrelated
inventory states reject. Exact PR evidence is recorded separately from
the semantic inventory contract. This correction does not edit Stdlib.
