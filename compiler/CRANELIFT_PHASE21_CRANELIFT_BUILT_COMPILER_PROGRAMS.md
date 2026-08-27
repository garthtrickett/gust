# Cranelift Phase 21 Cranelift-Built Compiler Program Compilation

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_cranelift_built_compiler_programs.py project`. Do not edit by hand.

- Contract: `phase21_cranelift_built_compiler_programs_v1`
- Status: `patch21_15_complete`
- Next patch: `21.16`
- Compiler source: `compiler/test_runner_entry.gst`
- Compiler build backend: `cranelift`
- Program backend: `cranelift`
- Semantic oracle: `mir_to_c_compiled_program_execution`
- Fallback: `explicit_cranelift_no_fallback`

## Selected accepted programs

- `positive`: `compiler/phase11_scalar_unsupported_multiply_source.gst` — exit 12, stdout hex ``, stderr hex ``.
- `resource`: `compiler/phase20_resource_scope_cleanup_source.gst` — exit 0, stdout hex `320a310a340a330a350a390a360a370a380a31300a`, stderr hex ``.
- `module`: `compiler/phase21_selected_declaration_source.gst` — exit 42, stdout hex ``, stderr hex ``.
- `typed_query`: `compiler/phase21_trusted_scope_positive.gst` — exit 41, stdout hex ``, stderr hex ``.

## Selected rejections

- `negative`: `compiler/phase13_scalar_invalid_operand_source.gst` — exit 1, diagnostic class `TypeMismatch`.
- `typed_query_negative`: `compiler/phase21_trusted_scope_absent_invalid.gst` — exit 1, diagnostic class `TenantScopeProvenance`.

## Comparison and boundary

- Every accepted program has byte-identical exit/stdout/stderr against the MIR-to-C oracle.
- The C-built and Cranelift-built compilers emit byte-identical native ELF program artifacts.
- Their Phase 9G linker stdout/stderr logs are present and byte-identical.
- Rejections have byte-identical stdout/stderr and happen before native-driver discovery.
- Successful subject routes leave no request, bundle, object, or generated-C residue.
- Patch 21.15 changes no Gust meaning, MIR operation, ABI/layout/runtime symbol, seed, default backend, fallback policy, Stdlib, or CR-15 authority, and does not begin Patch 21.16 or OD-15.
