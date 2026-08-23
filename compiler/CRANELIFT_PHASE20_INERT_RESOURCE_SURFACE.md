# Cranelift Phase 20 Inert Resource Declaration Surface

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_inert_resource_surface.py project`. Do not edit by hand.

- Authority version: `phase20_inert_resource_surface_v1`
- Status: `patch20_6_complete`
- Next patch: `20.7`
- Issue: `CR-5/#106`
- Enforcement enabled: `false`

## Additive surface

The parser and AST preserve `#[destructor(name)]`, `#[opaque]`, and
`#[private]`. Separate type metadata records the declarations without
registering a live linear destructor or applying access restrictions.
Malformed, duplicate, and conflicting spellings have stable parser
diagnostics.

## No-op boundary

A two-module witness directly constructs and accesses the declared
opaque representation and calls the declared private function, returning
42 exactly as the same unannotated program would. Patch 20.7 owns
migration under this no-op; Patch 20.8 alone owns enforcement.

The checked-in bootstrap seed compiles the extended self-hosted compiler
and remains unpublished until the isolated Patch 20.11 seed update.
