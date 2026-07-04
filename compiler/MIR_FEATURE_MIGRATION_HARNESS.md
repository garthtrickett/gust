# MIR Feature Migration Harness

MIR_FEATURE_MIGRATION_HARNESS_VERSION: 1
MIR_FEATURE_MIGRATION_PHASE: first-preservation-entry
MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: false

This file defines the Phase 5 feature migration harness contract.

Each migrated feature must get a preservation entry that proves this shape:

```text
source Gust fixture
  -> old AST-to-C expected behavior
  -> MIR lowering
  -> MIR verifier or focused MIR structural invariant guard
  -> MIR-to-C
  -> native execution
  -> same expected behavior
```

## Required preservation fields for future entries

Every migrated feature entry must name:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Registered preservation entries

### return_int_literal

- `feature_name`: `return_int_literal`
- `source_fixture`: `compiler/mir_feature_return_int_preservation_source.gst`
- `old_behavior_guard`: `guard-mir-feature-return-int-preservation`
- `mir_lowering_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_verifier_guard`: `guard-mir-lower-return-int-literal-smoke`
- `mir_to_c_guard`: `guard-mir-to-c-return-int-literal-smoke`
- `native_execution_guard`: `guard-mir-to-c-return-int-literal-native-smoke`
- `expected_behavior`: native executable exits with status `1`

The current verifier slot is backed by the focused return-int MIR structural invariant guard until a dedicated MIR verifier target exists.
# MIR Feature Migration Harness

MIR_FEATURE_MIGRATION_HARNESS_VERSION: 1
MIR_FEATURE_MIGRATION_PHASE: shell-only
MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: true

This file defines the Phase 5 feature migration harness contract without migrating any additional AST-to-C feature yet.

Each migrated feature must eventually get a preservation entry that proves this shape:

```text
source Gust fixture
  -> old AST-to-C expected behavior
  -> MIR lowering
  -> MIR verifier
  -> MIR-to-C
  -> native execution
  -> same expected behavior
```

## Required preservation fields for future entries

Every migrated feature entry must name:

- `feature_name`
- `source_fixture`
- `old_behavior_guard`
- `mir_lowering_guard`
- `mir_verifier_guard`
- `mir_to_c_guard`
- `native_execution_guard`
- `expected_behavior`

## Current shell status

No feature preservation entries are registered in this step.
This is intentional: Step 1 adds only the harness shell and a surface guard.

The first real preservation entry should be added in the next step for the existing tiny `return 1` MIR-to-C path.
