# Cranelift Experiment Manifest

CRANELIFT_EXPERIMENT_MANIFEST_VERSION: 1
CRANELIFT_EXPERIMENT_PHASE: phase9-inert-backend-surface-entry
CRANELIFT_EXPERIMENT_STATUS: inert_backend_surface
CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false
CRANELIFT_EXPERIMENT_CODEGEN_STATUS: none
CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: inert
CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c
CRANELIFT_EXPERIMENT_ALLOWED_GUARD: guard-cranelift-experiment-manifest-surface
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface
MIR_TO_C_BORING_GATE: guard-mir-to-c-boring-surface

This manifest starts Phase 9 without adding Cranelift code generation.

The Cranelift backend experiment has an inert backend surface at this step. The primary compiler route remains MIR-to-C. The MIR feature migration suite must continue to validate the retired Phase 8 features through MIR-owned routed execution.

## Step 2 constraints

- Cranelift is disabled by default.
- No Cranelift codegen entry point exists yet.
- No Cranelift Cargo dependency is allowed yet.
- No production compiler path may route to Cranelift yet.
- No `guard-cranelift-*` recipe is allowed except `guard-cranelift-experiment-manifest-surface` and `guard-cranelift-backend-surface`.
- `guard-mir-to-c-boring-surface` remains the prerequisite gate before backend implementation work starts.

## Allowed Step 2 surface

allowed_manifest: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md
allowed_guard: guard-cranelift-experiment-manifest-surface
allowed_backend_surface_guard: guard-cranelift-backend-surface
allowed_status: inert_backend_surface
allowed_backend_surface_status: inert
allowed_primary_route: mir_to_c

## Forbidden Step 2 surface

forbidden_codegen_status: implemented
forbidden_default_enabled: true
forbidden_production_route: cranelift
forbidden_dependency: cranelift
forbidden_backend_codegen_entry: cranelift_codegen
forbidden_native_smoke_prefix: guard-cranelift-return
