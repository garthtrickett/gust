# Gust Cranelift experiment

This crate is intentionally separate from the root Gust compiler crate.

It exists only to establish the Cranelift dependency beachhead for the
experimental backend path. Production Gust codegen must continue to route
through MIR-to-C until a later explicit step wires a real Cranelift backend.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```