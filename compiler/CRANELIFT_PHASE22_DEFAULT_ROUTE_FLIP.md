# Cranelift Phase 22.6 — Default Route Flip

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_default_route_flip_v1`
- Status: `implementation_complete`
- Next action: `patch22_6a_default_route_bootstrap_seed_reconvergence`
- Observed main: `8b2135ac664dfdeb32c2fd5ca28cc43bbf80ed3b`
- Predecessor: `phase22_preflip_default_cohort_v1`
- Implementation PR/base/head: `#259` / `8b2135ac664dfdeb32c2fd5ca28cc43bbf80ed3b` / `40be16fd5eb190d3c468fc8e4c5652d61ba5ec43`
- Merge commit: `e521f4f660acf59aff7e07f79a9567c73ffb0b2b`
- Bootstrap seed changed in implementation patch: `false`

## Route

- Default backend: `cranelift`
- Default/explicit native route: `identical_shared_post_semantic_pipeline_route`
- Explicit C spellings: `mir-to-c, c`
- Explicit C role: `retained_semantic_oracle`
- Native output: `source_directory_and_exact_terminal_dot_gst_stem`
- Native package: `executable_relative_three_artifact_sibling_package`
- Fallback: `forbidden`
- Bootstrap route: `explicit_mir_to_c`

## Evidence

- Native artifact identity: `byte_identical`
- Native execution identity: `identical`
- Native failure identity: `identical`
- Explicit C: `byte_identical_to_each_other_and_frozen_preflip_corpus`
- `compiler/phase11_scalar_unsupported_multiply_source.gst`: `c74ead80aa965e5c8dd353b87a89f971707f1de614cafe69f4efbd8c517ec91b`
- `compiler/phase20_resource_scope_cleanup_source.gst`: `c25415ff5f05b387b151d04f3b3ea3c8a9264bfd38c4573ac391a8a17ce8bdda`
- `compiler/phase21_selected_declaration_source.gst`: `1a6c3a6c3d1ef72d0cc4653fb77fd4c37d06c8129664f9aab628ab12b5ad5682`
- `compiler/phase21_trusted_scope_positive.gst`: `ad02e6f013b45cfc30d8e413b4dee7cb16f023cb377aeadfe38a156809d437fe`

Backend selection remains after the shared semantic pipeline. This patch
changes routing policy and active help only: it adds no source meaning,
canonical MIR, lowering, ABI/layout, runtime symbol, target, linker, or
bootstrap-seed change. Patch 22.6a remains a separate generated-seed patch.
