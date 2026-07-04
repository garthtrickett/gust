// Gust MIR scaffold.
//
// MIR is the lowered executable IR between the typechecked AST and backend
// emission. Phase 1 is intentionally inert: this file defines the future home
// for MIR data structures, but no production compiler path should depend on it
// yet.
//
// Planned pipeline:
//
//   typechecked AST / typed high-level representation
//     -> Gust MIR
//     -> MIR verifier
//     -> C backend first
//     -> Cranelift backend later
//
// Phase 1 rule:
//   Do not add AST-to-MIR lowering, MIR-to-C emission, Cranelift integration,
//   or production codegen dependencies in this file yet.
