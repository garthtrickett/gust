# Cranelift Phase 19 Retired-Prototype Absence Contract

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_retired_prototype_absence.py project`. Do not edit by hand.

- Contract: `phase19_retired_prototype_absence_v1`
- Status: `ready_for_patch19_8`
- Next patch: `19.8`
- Live compiler scope: `self_hosted_compiler_only`

## Retired root package

These paths must remain absent:

- `Cargo.toml`
- `Cargo.lock`
- `src/ast.rs`
- `src/codegen.rs`
- `src/codegen_runtime.rs`
- `src/lexer.rs`
- `src/lib.rs`
- `src/main.rs`
- `src/parser.rs`
- `src/resolver.rs`
- `src/token.rs`
- `src/typechecker.rs`
- `src/typechecker/monomorphize.rs`
- `src/typechecker/types.rs`
- `src/typechecker/visitor.rs`

## Preserved boundaries

These live runtime and backend paths are outside the removal boundary:

- `src/runtime.c`
- `src/runtime/*.c`
- `src/runtime/rust/`
- `compiler/experiments/cranelift/`

## Current semantic evidence

Phase 19 registry projections and current-semantic documents are checked
against the retired path list. The sole exception is
`docs/RUST_PROTOTYPE_REMOVAL.md`, which records the completed
removal rather than describing a live compiler implementation.

No Gust syntax, type rule, MIR instruction, ABI, layout, runtime symbol,
target policy, linker policy, compiler source, or bootstrap seed changed.
