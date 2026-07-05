# Cranelift Experiment Manifest

<!-- Step 11 real conditional-branch object smoke sync tokens. -->
CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_object_smoke
The only allowed real Cranelift codegen entry point is compiler/experiments/cranelift/src/main.rs for return-int, local-binding/read, and conditional-branch object emission.
allowed_codegen_status: return_int_local_binding_branch_object_smoke
allowed_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs
allowed_branch_object_artifact: build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch.o

CRANELIFT_EXPERIMENT_MANIFEST_VERSION: 1
CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry
CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke
CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false
CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only
CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: differential_native_smoke
CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c
CRANELIFT_EXPERIMENT_ALLOWED_GUARD: guard-cranelift-experiment-manifest-surface
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface
CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_BRANCH_NATIVE_GUARD: guard-cranelift-conditional-branch-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_DIFFERENTIAL_NATIVE_GUARD: guard-cranelift-mir-to-c-differential-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite
CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_BEACHHEAD_GUARD: guard-cranelift-dependency-beachhead
MIR_TO_C_BORING_GATE: guard-mir-to-c-boring-surface

This manifest starts Phase 9 without adding Cranelift code generation.

The Cranelift backend experiment now has fixture-only return-int, local-binding, and conditional-branch native smoke lanes. The primary compiler route remains MIR-to-C. The MIR feature migration suite must continue to validate the retired Phase 8 features through MIR-owned routed execution.

## Step 5 constraints

- Cranelift is disabled by default.
- No production Cranelift codegen entry point exists yet. The only allowed real Cranelift codegen entry point is compiler/experiments/cranelift/src/main.rs for return-int and local-binding/read object emission
- No root Cranelift Cargo dependency is allowed yet. Cranelift dependencies are allowed only under compiler/experiments/cranelift/.
- No production compiler path may route to Cranelift yet.
- No `guard-cranelift-*` recipe is allowed except `guard-cranelift-experiment-manifest-surface`, `guard-cranelift-backend-surface`, `guard-cranelift-dependency-beachhead`, `guard-cranelift-experimental-backend-suite`, `guard-cranelift-return-int-native-smoke`, `guard-cranelift-local-binding-native-smoke`, `guard-cranelift-local-binding-read-native-smoke`, `guard-cranelift-conditional-branch-native-smoke`, `guard-cranelift-branch-native-smoke`, `guard-cranelift-mir-to-c-differential-native-smoke`, and `guard-cranelift-differential-native-smoke`.
- `guard-mir-to-c-boring-surface` remains the prerequisite gate before backend implementation work starts.

## Allowed Step 5 surface

allowed_manifest: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md
allowed_guard: guard-cranelift-experiment-manifest-surface
allowed_backend_surface_guard: guard-cranelift-backend-surface
allowed_return_int_native_guard: guard-cranelift-return-int-native-smoke
allowed_local_binding_native_guard: guard-cranelift-local-binding-native-smoke
allowed_branch_native_guard: guard-cranelift-conditional-branch-native-smoke
allowed_differential_native_guard: guard-cranelift-mir-to-c-differential-native-smoke
allowed_backend_suite_guard: guard-cranelift-experimental-backend-suite
allowed_dependency_beachhead_guard: guard-cranelift-dependency-beachhead
allowed_status: mir_to_c_differential_native_smoke
allowed_codegen_status: return_int_local_binding_branch_differential_fixture_only
allowed_backend_surface_status: differential_native_smoke
allowed_primary_route: mir_to_c
allowed_return_int_fixture: tiny_cranelift_return_int
allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs
allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o
allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs
allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o
allowed_local_binding_fixture: tiny_cranelift_local_binding_read
allowed_branch_fixture: tiny_cranelift_conditional_branch
allowed_differential_return_int_pair: tiny_cranelift_return_int == tiny_return_int
allowed_differential_local_binding_pair: tiny_cranelift_local_binding_read == tiny_local_binding_read
allowed_differential_branch_pair: tiny_cranelift_conditional_branch == tiny_conditional_branch
allowed_differential_return_int_pair: tiny_cranelift_return_int == tiny_return_int
allowed_differential_local_binding_pair: tiny_cranelift_local_binding_read == tiny_local_binding_read
allowed_differential_branch_pair: tiny_cranelift_conditional_branch == tiny_conditional_branch

## Forbidden Step 5 surface

forbidden_codegen_status: implemented
forbidden_default_enabled: true
forbidden_production_route: cranelift
forbidden_root_dependency: cranelift
allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml
allowed_experiment_dependency_lockfile: compiler/experiments/cranelift/Cargo.lock
allowed_experiment_dependency_guard: guard-cranelift-dependency-beachhead
forbidden_production_backend_codegen_entry: cranelift_codegen
forbidden_production_route: cranelift

## Step 10 real Cranelift local-binding/read object smoke surface

STEP10_CRANELIFT_LOCAL_BINDING_OBJECT_SMOKE_SURFACE: synced

CRANELIFT_EXPERIMENT_MANIFEST_VERSION: 1
CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry
CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke
CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false
CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only
CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: differential_native_smoke
CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c
CRANELIFT_EXPERIMENT_ALLOWED_GUARD: guard-cranelift-experiment-manifest-surface
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface
CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_BRANCH_NATIVE_GUARD: guard-cranelift-conditional-branch-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_DIFFERENTIAL_NATIVE_GUARD: guard-cranelift-mir-to-c-differential-native-smoke
CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite
CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_BEACHHEAD_GUARD: guard-cranelift-dependency-beachhead
MIR_TO_C_BORING_GATE: guard-mir-to-c-boring-surface

Cranelift is disabled by default.
No production Cranelift codegen entry point exists yet.
The only allowed real Cranelift codegen entry point is compiler/experiments/cranelift/src/main.rs for return-int and local-binding/read object emission.
No production compiler path may route to Cranelift yet.
No `guard-cranelift-*` recipe is allowed except `guard-cranelift-experiment-manifest-surface`, `guard-cranelift-backend-surface`, `guard-cranelift-dependency-beachhead`, `guard-cranelift-experimental-backend-suite`, `guard-cranelift-return-int-native-smoke`, `guard-cranelift-local-binding-native-smoke`, `guard-cranelift-local-binding-read-native-smoke`, `guard-cranelift-conditional-branch-native-smoke`, `guard-cranelift-branch-native-smoke`, `guard-cranelift-mir-to-c-differential-native-smoke`, and `guard-cranelift-differential-native-smoke`.

allowed_manifest: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md
allowed_guard: guard-cranelift-experiment-manifest-surface
allowed_backend_surface_guard: guard-cranelift-backend-surface
allowed_return_int_native_guard: guard-cranelift-return-int-native-smoke
allowed_local_binding_native_guard: guard-cranelift-local-binding-native-smoke
allowed_branch_native_guard: guard-cranelift-conditional-branch-native-smoke
allowed_differential_native_guard: guard-cranelift-mir-to-c-differential-native-smoke
allowed_backend_suite_guard: guard-cranelift-experimental-backend-suite
allowed_dependency_beachhead_guard: guard-cranelift-dependency-beachhead
allowed_status: mir_to_c_differential_native_smoke
allowed_codegen_status: return_int_local_binding_branch_differential_fixture_only
allowed_backend_surface_status: differential_native_smoke
allowed_primary_route: mir_to_c
allowed_return_int_fixture: tiny_cranelift_return_int
allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs
allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o
allowed_local_binding_fixture: tiny_cranelift_local_binding_read
allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs
allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o
allowed_branch_fixture: tiny_cranelift_conditional_branch
allowed_differential_return_int_pair: tiny_cranelift_return_int == tiny_return_int
allowed_differential_local_binding_pair: tiny_cranelift_local_binding_read == tiny_local_binding_read
allowed_differential_branch_pair: tiny_cranelift_conditional_branch == tiny_conditional_branch
allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml
allowed_experiment_dependency_lockfile: compiler/experiments/cranelift/Cargo.lock
allowed_experiment_dependency_guard: guard-cranelift-dependency-beachhead
forbidden_root_dependency: cranelift
forbidden_production_backend_codegen_entry: cranelift_codegen
forbidden_production_route: cranelift

