# Cranelift Phase 20 Resource Declaration Enforcement

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_resource_enforcement.py project`. Do not edit by hand.

- Authority version: `phase20_resource_declaration_enforcement_v1`
- Status: `patch20_8_complete`
- Next patch: `20.9`
- Issue: `CR-5/#106`
- Enforcement enabled: `true`

## Declaration and module authority

A declared destructor must exist in the resource type's module, take
exactly one owned value of that resource type, return `Void`, and be a
safe non-extern cleanup function. Only identities passing that validation
enter the compiler-cleanup allowlist; ordinary callers receive no bypass.

Opaque types can be constructed and their fields accessed only inside
their defining module. Private functions can be called or referenced only
there. A module may therefore expose an acquirer and safe read API without
exposing a forgeable representation or callable cleanup primitive.

## Backend-neutral evidence

The positive two-module program returns 47 through default and explicit
MIR-to-C. Every negative produces one identical shared-frontend diagnostic
for default MIR-to-C, explicit MIR-to-C, and explicit Cranelift before
backend selection. The Patch 20.6 no-op witness is reclassified and now
produces exactly the three construction, field, and private-call errors.

Patch 20.9 still owns acquisition-site obligations; Patch 20.10 still
owns generic scope-exit cleanup and destructor invocation.
