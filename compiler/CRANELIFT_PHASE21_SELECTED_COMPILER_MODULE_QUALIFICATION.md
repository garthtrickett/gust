# Cranelift Phase 21 Selected Compiler-Module Native Qualification

Generated from scripts/cranelift_feature_registry.json by
scripts/phase21_selected_compiler_module_qualification.py project.
Do not edit by hand.

- Contract: phase21_selected_compiler_module_qualification_v1
- Status: patch21_13_complete
- Next patch: 21.13a
- Observed main: 45a635c1acbf294997d952701d8ad12c934686c9
- Selected order: lexer.gst, parser.gst, resolver.gst, typechecker.gst, mir.gst, codegen.gst

## Generic declaration admission

- Ordinary struct/enum declarations own no executable MIR.
- Every function use still passes the generic signature and body lowerers.
- The declaration witness exits 42 with empty output through both backends.

## Selected module slices

1. lexer — lexer.gst
   - Reachable graph: 2 modules / 1 import edges
   - MIR-to-C: 32882 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 60ms / 9088KiB; Cranelift 80ms / 7808KiB
2. parser — parser.gst
   - Reachable graph: 5 modules / 7 import edges
   - MIR-to-C: 290133 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 420ms / 92288KiB; Cranelift 190ms / 68096KiB
3. resolver — resolver.gst
   - Reachable graph: 3 modules / 3 import edges
   - MIR-to-C: 46521 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 20ms / 12416KiB; Cranelift 10ms / 9600KiB
4. typechecker — typechecker.gst
   - Reachable graph: 4 modules / 5 import edges
   - MIR-to-C: 1397142 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 4340ms / 1253120KiB; Cranelift 1610ms / 1139072KiB
5. mir — mir.gst
   - Reachable graph: 16 modules / 35 import edges
   - MIR-to-C: 3133238 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 5520ms / 912512KiB; Cranelift 3230ms / 768896KiB
6. codegen — codegen.gst
   - Reachable graph: 9 modules / 15 import edges
   - MIR-to-C: 2423333 generated-C bytes; linked executable exits 0 with empty output
   - Explicit Cranelift: source_or_type_failure at before_driver_discovery; canonical MIR absent_before_driver_discovery; artifact absent
   - Diagnostic: Native backend canonical MIR verification failed: module function uses an unsupported scalar signature
   - Local baselines: MIR-to-C 7990ms / 1682816KiB; Cranelift 4030ms / 1492992KiB

## Generic capability disposition

- Top-level struct/enum declaration admission: implemented in Patch 21.13.
- Non-scalar compiler-module signatures: one generic required capability assigned to Patch 21.14.
- Large-function/registry behavior is not yet observable because signature admission rejects first.
- The historical Phase 21 opening and Patch 21.12 support records remain recorded; their live guards now follow this successor diagnostic.

Patch 21.13 changes no Gust source meaning, canonical MIR operation,
ABI/layout/runtime symbol, bootstrap seed, default backend, fallback,
Stdlib, CR-15, or Patch 21.13a work.
