# Cranelift Experiment Manifest

CRANELIFT_EXPERIMENT_MANIFEST_VERSION: 1
CRANELIFT_EXPERIMENT_PHASE: phase9-local-binding-native-smoke-entry
CRANELIFT_EXPERIMENT_STATUS: local_binding_native_smoke
CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false
CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_and_local_binding_fixture_only
CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: local_binding_native_smoke
CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c
CRANELIFT_EXPERIMENT_ALLOWED_GUARD: guard-cranelift-experiment-manifest-surface
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface
CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke
MIR_TO_C_BORING_GATE: guard-mir-to-c-boring-surface

This manifest starts Phase 9 without adding Cranelift code generation.

The Cranelift backend experiment now has fixture-only return-int and local-binding native smoke lanes. The primary compiler route remains MIR-to-C. The MIR feature migration suite must continue to validate the retired Phase 8 features through MIR-owned routed execution.

## Step 4 constraints

- Cranelift is disabled by default.
- No Cranelift codegen entry point exists yet.
- No Cranelift Cargo dependency is allowed yet.
- No production compiler path may route to Cranelift yet.
- No `guard-cranelift-*` recipe is allowed except `guard-cranelift-experiment-manifest-surface`, `guard-cranelift-backend-surface`, `guard-cranelift-return-int-native-smoke`, and `guard-cranelift-local-binding-native-smoke`.
- `guard-mir-to-c-boring-surface` remains the prerequisite gate before backend implementation work starts.

## Allowed Step 4 surface

allowed_manifest: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md
allowed_guard: guard-cranelift-experiment-manifest-surface
allowed_backend_surface_guard: guard-cranelift-backend-surface
allowed_return_int_native_guard: guard-cranelift-return-int-native-smoke
allowed_local_binding_native_guard: guard-cranelift-local-binding-native-smoke
allowed_status: local_binding_native_smoke
allowed_codegen_status: return_int_and_local_binding_fixture_only
allowed_backend_surface_status: local_binding_native_smoke
allowed_primary_route: mir_to_c
allowed_return_int_fixture: tiny_cranelift_return_int
allowed_local_binding_fixture: tiny_cranelift_local_binding_read

## Forbidden Step 4 surface

forbidden_codegen_status: implemented
forbidden_default_enabled: true
forbidden_production_route: cranelift
forbidden_dependency: cranelift
forbidden_backend_codegen_entry: cranelift_codegen
forbidden_production_route: cranelift
