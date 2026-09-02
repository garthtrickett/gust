# Gust Web Slice 1 — Schema and boundary validation

**Status:** planned after the shared-contract and codec foundation in
`docs/WEB_SLICE_0.md`; not active.

This is the implementation roadmap for Gust's Zod-class outcome: untrusted data
crosses a declared boundary only after it has been parsed and validated into an
ordinary Gust type. Application authors define the type once. The compiler
derives the schema, parser, validator, codecs and boundary adapters.

This is not a plan to embed Zod, reproduce its fluent runtime API, or create a
second type system beside Gust's. It applies the decisions in `docs/VISION.md`
§§14–15: derived type surfaces are bounded compiler work, deterministic and
inspectable, rather than a user-programmable compile-time language.

---

## Product contract

The conceptual application flow is:

```text
ordinary Gust struct or enum
  → compiler-owned constraint metadata
    → generated parser and validator
      → Result[TrustedValue, ValidationErrors]
        → HTTP / RPC / form handler
```

The exact source spelling for constraints and invocation belongs to the active
roadmap patch that introduces it. This record does not choose attributes,
special declarations, or a `validate[T]` syntax prematurely.

The invariant is stronger than “the shape looks right”:

- raw JSON, form fields, route parameters, headers and other external values are
  untrusted input;
- successful parsing produces the declared Gust type, not an untyped map with a
  later cast;
- failure produces structured, serializable errors with stable paths and codes;
- client-side validation improves interaction, but the server boundary remains
  authoritative; and
- one type and constraint declaration drives every generated consumer.

## Initial constraint vocabulary

Keep the first vocabulary deliberately bounded:

- required and optional fields;
- strings with minimum and maximum length, pattern and named format checks;
- integers and other supported numbers with inclusive and exclusive bounds;
- booleans, enums, tagged unions and nested records;
- lists with element validation and size bounds; and
- explicit unknown-field policy.

Email, URL and similar named formats must have one documented implementation and
stable diagnostic identity. Arbitrary user callbacks, asynchronous refinements,
runtime reflection and a general schema-programming language are outside the
initial surface.

## Patch sequence

### W1.0 — Boundary and serializability contract

- Define trusted versus untrusted values at application boundaries.
- Classify the Gust types that may cross those boundaries.
- Reject pointers, references, arenas, resources, function values and opaque
  native handles with a stable compile-time diagnostic.
- Freeze positive and negative fixtures before generation work begins.

**Exit gate:** every supported and forbidden boundary type has one compiler-owned
classification and a falsifying fixture.

### W1.1 — Schema and constraint derivation

- Derive a closed schema graph from ordinary structs, enums and supported
  containers.
- Add the bounded constraint vocabulary above without user-defined compile-time
  execution.
- Diagnose contradictory, inapplicable and unsupported constraints at compile
  time.
- Make the derived schema inspectable through deterministic compiler output.

**Exit gate:** valid declarations produce a reproducible schema graph and invalid
declarations fail before application execution.

### W1.2 — Generated parsing and validation

- Generate monomorphic parsers and validators for each used boundary type.
- Return the typed value only after all required parsing and validation succeeds.
- Preserve all useful sibling errors rather than reporting only the first field.
- Bound nesting, collection size and error accumulation so hostile input cannot
  turn validation into uncontrolled resource use.

**Exit gate:** valid input becomes the exact declared type; malformed and
constraint-invalid input cannot reach the handler as that type.

### W1.3 — Structured validation errors

- Define stable field paths, machine-readable codes, human-facing messages and
  optional constraint metadata.
- Preserve nested record, list-index and tagged-union locations.
- Version the serialized error contract from its first consumer.
- Keep localization and presentation outside the semantic error identity.

**Exit gate:** server, client and tests consume one deterministic error shape
without parsing prose.

### W1.4 — Codec and schema artifacts

- Generate JSON decoding and encoding from the same schema graph.
- Emit a versioned, reproducible schema manifest for tooling and generated
  clients.
- Add round-trip, malformed-input and schema-version conformance checks.
- Do not make JSON the internal representation of a validated Gust value.

**Exit gate:** codecs, validators and the manifest agree for every selected type,
and stale or incompatible generated consumers fail clearly.

### W1.5 — HTTP and RPC boundary integration

- Apply parsing and validation automatically to the input locations declared by
  a handler.
- Do not invoke application logic on an invalid request.
- Map validation failures to typed structured responses without conflating them
  with authentication, authorization or domain failures.
- Generate client request and response types from the same contract.

**Exit gate:** one declared boundary type governs server input, generated client
input and transport validation with no handwritten duplicate schema.

### W1.6 — Form integration

- Reuse the same constraints for client interaction and authoritative server
  validation.
- Map structured field paths to accessible form errors.
- Support partial interaction state without pretending a partially completed
  form is the final trusted type.
- Prove that bypassing client validation changes neither server acceptance nor
  the error contract.

**Exit gate:** forms provide immediate accessible feedback while the server
remains the final and identical validation authority.

### W1.7 — Closure and generated conformance

- Generate positive, negative, boundary, nesting and resource-limit tests from
  each selected schema.
- Verify deterministic output and bootstrap-safe compiler derivation.
- Publish the supported constraint and boundary-type matrix.
- Record every deferred refinement class rather than accepting it silently.

**Exit gate:** the selected matrix is green end to end, generated artifacts are
reproducible, and no application path needs a handwritten parallel schema.

---

## Dependencies and sequencing

This slice depends on:

- the shared-type scanner and monomorphic codec direction recorded by Web Slice
  0;
- a usable `Result` and absence model for typed success and failure;
- a schema-agnostic JSON reader and writer;
- compiler-owned derivation infrastructure; and
- the relevant HTTP boundary before W1.5, plus the browser/form surface before
  W1.6.

Those dependencies do not make this part of Cranelift Phases 24, 24.5 or 25.
Backend retirement and compiler consolidation should finish on their own
evidence. This application slice may be activated only in a roadmap that owns
the shared web boundary and its compiler derivations.

## Non-goals

- No runtime schema-builder DSL.
- No duplicated “schema type” separate from the Gust type.
- No arbitrary user code during derivation.
- No validation-based authorization or tenant trust.
- No automatic coercion whose lossy behaviour is hidden.
- No promise of prolonged-offline conflict resolution or collaborative-document
  merging; those belong to the separate sync capability.
- No claim of formal verification.

The intended result is the part developers value in Zod—one readable contract,
safe parsing, precise errors and excellent boundary ergonomics—implemented in a
way that fits Gust's compiler-owned capability philosophy.
