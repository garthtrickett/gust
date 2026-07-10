# Gust Cranelift experiment

This crate is intentionally separate from the root Gust compiler crate.

It started as the Cranelift dependency beachhead for the experimental
backend path. Production Gust codegen must continue to route through MIR-to-C
until a later explicit step wires a real Cranelift backend.

Step 9 adds the first real Cranelift object emission smoke: a tiny exported
`tiny_cranelift_return_int` function that returns `1`. The justfile links that
object with a C shim only to execute the native smoke; the function body itself
is emitted by Cranelift.

The Phase 9C+ roadmap promotes compiler-owned MIR ingestion to the main
experimental seam. New lanes should prefer a fixture produced by
`compiler/mir.gst`, consumed by this crate, emitted as an object, linked with a
native shim, and checked for its expected result instead of adding another
bespoke translator seed. All seven Phase 9C differential candidates now use
that seam: return-int literal, local-binding/read, conditional branch, block
jump, provenance metadata, resource metadata, and native-boundary metadata.
The Phase 9B translator seeds remain frozen historical experiment coverage.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
