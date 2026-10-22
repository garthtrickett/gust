# First-release tagged success representation — OD-21 decision

**Status: RESOLVED 2026-10-22 — operator selected B, branded Index success.**
[VISION §0.15](VISION.md#015-open-decisions) owns the status. The operator's
explicit choice was “od21: ticket”; it is separate from OD-20's metadata,
failure and copy decisions.

Success carries `Index[std.Vector[byte, ctx], ctx]` into the caller's explicit
output arena. The Vector must be complete, copy-out successful and native
temporary cleanup finished before the wrapper publishes that Index. The caller
uses the existing checked arena access to obtain the Vector. Error carries no
usable output Index. This selects the public representation; implementation
and qualification remain with a separately activated Stdlib owner.

## The boundary

[The first-release FFI contract](FIRST_RELEASE_FFI_CONTRACT.md) §5 selects
Vector storage and an explicit output arena, with a checked success Vector or
classified error in an existing tagged result type. It leaves final public
types and spelling to Stdlib after merged compiler support.

The current frontend rejects an ordinary Vector directly inside a tagged
success payload. Both ordinary enum registration and generic instantiation
check resolved struct payloads with more than two fields, with a field-based
`tag` exemption. `env_register_std_templates` gives Vector its data, length,
capacity and arena fields. The preserved source experiment encountered that
admission error before native emission; no executable was produced.

That is a representation and contract question. It is not permission to relax
an enum guard or quietly replace the promised public value with a handle.

## Alternatives

| Option | Required authority and evidence | Cost or risk |
| --- | --- | --- |
| A — direct Vector success | Keep the direct-value interpretation and qualify generic large aggregate enum payload support through Cranelift. Preserve layout, native return/match/move behavior, brands and non-laundering; prove surviving rejections can still fail and qualify the native fixed point and owning CI. | A compiler prerequisite beyond the collection invariant repair. Existing native layout machinery is a starting point, not proof that the frontend guard is dispensable. No Vector-specific exception. |
| B — branded Index success | Explicitly permit a success value containing an existing `Index[std.Vector[byte, ctx], ctx]` into the caller's output arena. Publish the completed Vector through checked arena operations only after successful copy-out and cleanup. Stdlib chooses and tests its public surface after merged compiler support. | Requires an explicit release-contract interpretation/change. It adds an arena lookup to access success; existing separate mechanisms do not qualify their combination or prove this public API safe. |

**Decision: B for the first release.** It uses the selected Vector storage and
existing branded indirection without requiring general by-value enum expansion. It must
not convert a native pointer into a safe Index, change arena/brand lifetime, or
publish partial output. Falsify the preference if the combined checked path
cannot preserve those properties or the required public behavior. Such a finding
must be reported before changing the selected public representation or semantics.

## Qualification and ownership

For the selected Index representation, qualify the complete public success/error
path, empty output, native failure, no partial publication, output-arena brand/escape
rejection, cleanup order, and return/move/access behavior. Keep allocator
exhaustion distinct from recoverable adapter errors. A raw-pointer or unsafe-only
public workaround does not satisfy the release contract.

Cranelift owns any required generic frontend/canonical/native capability and
its bootstrap evidence. Stdlib owns final public API ergonomics and tests once
its lane is activated and compiler support is merged. Docs/vision records the
decision and approved contract wording. This decision does not activate another
lane's roadmap; all full release gates remain open.

## Evidence and limits

Static audit baseline: merged main
`6bca6cdde2a3966758fc3fb40e04fc3115e270ad`, 2026-10-22.
`compiler/typechecker.gst` SHA-256 is
`ab588402efc7e0314bed2832255b3a31fc1c2fc1dec12ec83be11b072f09f303`.
The two payload-validation bodies and registered Vector fields were read.
The checked-in `tests/e2e_enum_indirection_pattern.gst` illustrates branded
Index storage in an enum but also uses internal unsafe tag/payload writes;
it does not by itself establish a complete safe wrapper or safe user-facing
enum construction. `tests/test_large_enum_variant_payload_rejected.gst`
preserves the direct large-payload rejection.

Historical retained artifacts below
`/home/gust/phase26-recovery/boot970ebe4e/` were digest-checked:

| Artifact | SHA-256 |
| --- | --- |
| `r2-tagged-result-contract-choice-v1.json` | `84df8a55296e47cca829b6819a4cccdbefebcbbf03080203498be86376e27ddf` |
| `r2-scoped-tagged-shape-capture-v3/output/result.json` | `20522d6b112a8266e826f3792afc3490ea0e7a8e29c180f48f59336124ac8ff4` |

The result records compiler exit 1 and no generated ELF. This registration
uses historical compile evidence and a current static read, not a new compiler
execution or a current-main end-to-end reproduction. The private artifacts
remain retained evidence rather than a clean-machine public proof.
