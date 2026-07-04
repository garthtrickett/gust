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