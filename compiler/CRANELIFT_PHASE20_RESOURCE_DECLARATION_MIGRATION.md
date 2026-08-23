# Cranelift Phase 20 Resource Declaration Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_resource_declaration_migration.py project`. Do not edit by hand.

- Authority version: `phase20_resource_declaration_migration_v1`
- Status: `patch20_7_complete`
- Next patch: `20.8`
- Issue: `CR-5/#106`
- Enforcement enabled: `false`

## Migrated source declarations

- `compiler/phase13_composition_resource_metadata_source.gst`
- `compiler/phase13_source_resource_metadata_source.gst`
- `compiler/phase13_resource_cleanup_deferred_source.gst`
- `compiler/future/phase14_resource_cleanup_source.gst`

Every compiler-owned `#[linear]` structure now declares an opaque
representation, a destructor name, and a same-module private cleanup
function with an owned resource parameter. The attributes remain inert
under Patch 20.6, so the existing programs retain their behavior.
The Phase 13 metadata route counts that matching private cleanup as a
declaration-only companion, preserving its established native parity.

## Directory metadata bridge

The synthesized `os_Dir_ctx` resource records inert destructor
`os.CloseDir` and opacity metadata alongside the existing live Phase 15
linear/destructor metadata. Its source compatibility, explicit close
behavior, cleanup scheduling, and diagnostics are unchanged.

The exact directory vocabulary cohort contains 22 compiler files. The
inventory guard derives both cohorts from live compiler sources and
rejects any unclassified declaration or directory use site.

Patch 20.8 alone owns enforcement of declaration, construction,
representation-access, and private-call rules.
Its positive module and intentional invalid declaration fixtures are
classified separately by the Patch 20.8 authority while remaining in
this exact compiler-owned `#[linear]` inventory.
