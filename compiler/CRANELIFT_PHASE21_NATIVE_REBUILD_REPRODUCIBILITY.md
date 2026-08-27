# Cranelift Phase 21 Native Rebuild Reproducibility Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_native_rebuild_reproducibility.py project`. Do not edit by hand.

- Contract: `phase21_native_rebuild_reproducibility_v1`
- Status: `patch21_16_complete`
- Next patch: `21.17`
- OD-15: `resolved_2026_08_27_strict_binary_identity`
- Compiler source: `compiler/test_runner_entry.gst`

## Selected authoritative criterion

Independent native compiler stages must be byte-identical when every
authoritative environment input is identical. A separately bounded
cross-machine or cross-toolchain semantic contract cannot substitute
for or weaken this Phase 21 closure gate.

## Native stage graph

- `N1a=packaged_MIR_to_C_built_compiler_to_Cranelift_native_compiler`
- `N1b=independent_packaged_MIR_to_C_built_compiler_to_Cranelift_native_compiler`
- `N2=N1a_to_Cranelift_native_compiler`
- `N3=N2_to_Cranelift_native_compiler`

## Pinned authoritative environment

- Source: `exact_clean_checked_out_workflow_head_for_every_stage`
- Runner: `ubuntu-24.04`
- Rust: `rustc 1.97.1 (8bab26f4f 2026-07-14)`
- Cargo: `cargo 1.97.1 (c980f4866 2026-06-30)`
- Cranelift: `0.131.0` with manifest SHA-256 `220aef9a4d2636505f2fa39137de12a0f00d836dd7971db2491cdee4a657d9a6` and lockfile SHA-256 `b40ceaa047c0260d5b4ce0f511ef9239ad7ca4b84375f7c5604f645980e8211f`
- Target and flags: `x86_64-unknown-linux-gnu` / `--backend cranelift`
- C toolchain: `cc 13.3.0` / `-O2 -Wall -pthread`
- Linker: `GNU ld 2.42`
- Runtime: `build/phase10-package/bin/gust-runtime-package.a`
- Normalized stage environment:
  - `LANG=C.UTF-8`
  - `LC_ALL=C.UTF-8`
  - `TZ=UTC`
  - `SOURCE_DATE_EPOCH=0`
  - `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
  - `CC=cc`
  - `CFLAGS=-O2 -Wall -pthread`
  - `RUSTUP_TOOLCHAIN=1.97.1`

## Measured decision evidence

- Artifact: `5696280` bytes, SHA-256 `5990f6afa108a577c88f93035999d1cb43e748611255031af44f0b2e3418f62e` across N1a/N1b/N2/N3.
- Help stdout SHA-256: `c8ff57e34bb17a5bb6c7af65b2d8c868db33ae80ee4872faa175ed92c7a77b07`; help stderr is empty across every stage.
- Observed elapsed ms: N1a `38320`, N1b `39485`, N2 `87197`, N3 `77380`.
- Observed peak child RSS: `4045952` KiB.
- Build diagnostics and Phase 9G linker logs are empty for every stage.
- The guard compares the live exact workflow-head artifacts; the observed
  hash records the decision evidence and does not freeze later source commits.

## Boundary

Patch 21.16 changes no accepted Gust meaning, MIR operation, ABI/layout/runtime
symbol, bootstrap seed, default backend, fallback policy, Stdlib, or CR-15
authority, and it does not begin Patch 21.17.
