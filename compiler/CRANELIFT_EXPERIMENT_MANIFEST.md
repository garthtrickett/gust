# Cranelift backend architecture manifest

CRANELIFT_ARCHITECTURE_MANIFEST_VERSION: 2
CRANELIFT_ARCHITECTURE_HIGH_LEVEL_STATUS: phase11_closed_phase12_5_framework_consolidated_phase13_opening_rebased_ready_for_patch13_1
CRANELIFT_ARCHITECTURE_BACKEND_ISOLATION: implementation_and_dependencies_live_under_compiler/experiments/cranelift
CRANELIFT_ARCHITECTURE_DEFAULT_BACKEND: mir-to-c
CRANELIFT_ARCHITECTURE_SUPPORTED_BACKEND_SELECTORS: mir-to-c,cranelift
CRANELIFT_ARCHITECTURE_WORKER_BOUNDARY: canonical_MIR_request_path_only_no_raw_source_fields
CRANELIFT_ARCHITECTURE_ARTIFACT_OWNERSHIP_BOUNDARY: compiler_owns_request_staging_linking_cleanup_and_atomic_executable_publication_worker_owns_requested_object_emission
CRANELIFT_ARCHITECTURE_NO_FALLBACK_POLICY: explicit_cranelift_success_deferral_or_failure_terminates_without_MIR-to-C_codegen
CRANELIFT_ARCHITECTURE_RUNTIME_PACKAGE_BOUNDARY: gust-native-backend_is_an_installed_sibling_or_absolute_GUST_NATIVE_BACKEND_DRIVER_no_PATH_search_or_auto_build
CRANELIFT_ARCHITECTURE_FEATURE_REGISTRY_AUTHORITY: scripts/cranelift_feature_registry.json
CRANELIFT_ARCHITECTURE_TEST_LEVEL_AUTHORITY: scripts/cranelift_test_levels.json
CRANELIFT_ARCHITECTURE_HISTORICAL_EVIDENCE_OWNER: scheduled_or_manual_Cranelift_Historical_Full

## Scope

This document records only stable backend architecture and policy. Active feature
rows, classifications, fixtures, route owners, and CI families live in
`scripts/cranelift_feature_registry.json`. Guard cost classes and CI ownership live
in `scripts/cranelift_test_levels.json`. Generated summaries are review artifacts,
not authorities.

## Backend selection and isolation

`mir-to-c` remains the default backend. `cranelift` is selected only through the
explicit backend selector and remains experimental. Cranelift implementation code
and Rust dependencies stay inside `compiler/experiments/cranelift`; the root
compiler does not link Cranelift libraries directly.

## Worker and artifact boundary

The compiler lowers source into canonical MIR before crossing the worker boundary.
The worker receives a request path and artifact metadata, never raw Gust source or
a source path. The worker emits the requested object. The compiler owns request
staging, object verification, linking, diagnostic capture, cleanup, and atomic
publication of the final executable.

## Fallback policy

Once explicit Cranelift selection begins, success, an unsupported-capability
deferral, or a classified failure terminates that backend attempt. It does not
enter MIR-to-C code generation as an implicit fallback.

## Runtime and package boundary

The native worker is distributed as `gust-native-backend` beside `gust`.
`GUST_NATIVE_BACKEND_DRIVER` may override it only with an absolute executable
path. There is no PATH search or automatic worker build during compilation.

## Phase status

Phase 11 is semantically closed for its canonical registry inventory. Phase 12.5
has consolidated verification ownership without changing compiler behavior.
The Phase 13 opening inventory is rebased onto that framework, preserves all
stable IDs and parent relationships, and is ready to resume at Patch 13.1.
Detailed historical decisions and evidence remain available through git history
and the explicit Level 3 historical suite.

