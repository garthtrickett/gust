# Cranelift Phase 21 Full Compiler Native Qualification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_full_compiler_native_qualification.py project`. Do not edit by hand.

- Contract: `phase21_full_compiler_native_qualification_v1`
- Status: `patch21_14_complete`
- Next patch: `21.15`
- Canonical format: `gust.compiler_executable_mir.v1`
- Target/object: `x86_64-unknown-linux-gnu` / `Elf`
- Oracle: `mir_to_c`
- Fallback: `explicit_cranelift_no_fallback`

## Qualified full-compiler projection

- Modules: 42
- Layouts: at least 788
- Enums: at least 40
- Functions: at least 1803
- Executable nodes: at least 247483
- Entry: `main`
- Symbol authority: `strict_payload_worker_rederived_outer_bundle_exports_main_only`

## Artifact and failure evidence

- Artifact: `ELF64` `DYN` `Advanced Micro Devices X86-64` executable exporting `main`.
- The qualified route emits no generated C and leaves no transient request, bundle, or object.
- The existing runtime archive supplies all eight registered object members; no runtime symbol is added.
- Malformed MIR exits 2 with byte-identical diagnostics and no object.
- The native artifact's help output is byte-identical to the MIR-to-C-built compiler.
- Frozen predecessor records remain historical; their live replay now requires supported native parity.
- Resource cleanup is transported from `typechecker_resource_cleanup_plans` with no backend inference.
- Normal exit ordering: `source_defers_then_scope_cleanup_plan`; return ordering: `all_active_source_defers_then_return_cleanup_plan`.
- Scalar user-main exit status follows `mir_to_c_gust_user_exit_status` and is returned after scheduler destruction; void main returns 0.

Patch 21.14 adds generic executable canonical-MIR production and native
lowering for the full compiler under existing Phase 14–16 authorities.
It changes no accepted Gust meaning, ABI/layout/runtime symbol, bootstrap
seed, default backend, fallback policy, Stdlib or CR-15 contract, and it
does not begin Patch 21.15.
