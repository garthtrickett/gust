# Cryptography and TLS provider architecture

**Status:** proposed platform prerequisite, recorded 2026-08-27. This note does
not activate implementation work, assign an active roadmap lane, authorize a new
dependency or runtime symbol, approve an FFI/layout change, or make a FIPS claim.
Any implementation that adds native symbols, resources, ABI, layout, FFI, or
effects must first receive the ownership decisions required by `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`.

## Proposal

Gust owns a small, typed, replaceable cryptography and TLS provider contract.
The first production provider should be a narrow C shim over a pinned, supported
OpenSSL 3 build. Production cryptographic primitives and TLS are not implemented
in Gust.

This uses the same replaceable-contract instinct as supplier adapters, but the
trust position is different:

- AWS, Stripe, email, and similar adapters sit behind external capability and
  data-egress boundaries.
- Cryptography and TLS execute inside the runtime and therefore form part of the
  platform's trusted computing base.
- An application uses safe Gust operations and never imports OpenSSL, selects
  arbitrary algorithms, manipulates native contexts, or receives raw provider
  pointers.

Gust may contain test-only reference implementations for education,
conformance, differential testing, or bootstrap diagnosis. They must be
impossible to select for production secrets, signatures, authentication, or
network traffic.

## Provider selection

### Initial provider: OpenSSL 3

Use the public high-level [`EVP`][openssl-evp] interfaces in `libcrypto` and the
public `libssl` TLS interfaces through a Gust-owned C shim. OpenSSL's [release
policy][openssl-releases] guarantees public API and ABI compatibility within one
major version, which makes a pinned supported 3.x line a materially better
runtime boundary than an unstable upstream snapshot.

The shim, rather than ordinary Gust code, owns provider initialization, native
context allocation, error-stack draining, cleanup, and translation into a small
Gust error taxonomy. Do not expose `EVP_*`, `SSL_*`, provider names, algorithm
name strings, `OSSL_PARAM`, native error codes, or native pointers as the Gust
API.

Gust Cloud should ship and attest one exact supported provider build. A
self-hosted deployment may use an explicitly supported system build only after
load-time version/capability checks and the guarantee ledger records exactly
what was loaded. "Whatever `libcrypto` happens to be installed" is not a
reproducible provider policy.

### Later provider: AWS-LC LTS

[AWS-LC][aws-lc] is a plausible second provider when measured performance,
platform support, or a deliberate FIPS deployment profile justifies it. Its
[LTS policy][aws-lc-versioning] promises a multi-year stable ABI. Rolling
mainline and LTS are different consumption choices and must not be silently
interchanged.

The provider must pass the same Gust corpus before use. An OpenSSL-compatible
header surface does not by itself prove identical TLS policy, error behavior,
algorithm availability, key validation, or FIPS status.

### Rejected as initial boundaries

- **BoringSSL:** [Google states][boringssl] that it is not intended for general
  third-party use and provides no API or ABI stability guarantee. It is suitable
  as an upstream implementation reference, not as Gust's first supported binary
  boundary.
- **`ring`:** [`ring`][ring] exposes a Rust crate rather than a supported C ABI
  and its own project describes itself as an experiment. Binding it would
  require a Rust-to-C wrapper plus Rust build/runtime integration without
  removing the need for a stable Gust shim.
- **A home-grown production provider:** standards conformance vectors do not
  establish side-channel resistance, platform entropy quality, secure key
  handling, certificate validation, maintenance response, or cryptographic
  module validation.

## Initial contract

The initial contract is concrete rather than a generic "choose an algorithm"
API:

```text
crypto.random_bytes(output)
crypto.sha256(input) -> Digest256
crypto.hmac_sha256(key, input) -> Mac256
crypto.pbkdf2_hmac_sha256(password, salt, iterations, output)
crypto.constant_time_equal(left, right) -> bool
crypto.secure_clear(secret_buffer)

tls.connect(socket, server_name, trust_policy, deadline) -> TlsConnection
tls.read(connection, output, deadline) -> ReadResult
tls.write(connection, input, deadline) -> WriteResult
tls.close(connection)
```

Names above describe the planned boundary, not authorized Gust syntax or runtime
symbols.

The first primitive cohort is intentionally the intersection needed by the
first full-stack integrations:

| Consumer | Required operations |
| --- | --- |
| PostgreSQL SCRAM-SHA-256 | secure randomness, SHA-256, HMAC-SHA256, PBKDF2-HMAC-SHA256, constant-time comparison, TLS |
| AWS SigV4 | SHA-256, HMAC-SHA256, TLS |
| Stripe webhook authentication | HMAC-SHA256, constant-time comparison |
| Stripe and S3 HTTP clients | TLS |

Base64 and hexadecimal encoding are protocol encodings, not cryptographic
primitives. They may be implemented in safe Gust code with strict bounds and
canonicalization tests; secret-bearing temporary buffers still follow the
secret and cleanup rules.

## What remains in Gust

The native provider performs cryptographic computation and the TLS protocol.
Gust still owns the higher-level, reviewable state machines and policies:

- PostgreSQL SCRAM message sequencing, nonce/proof validation, and iteration
  bounds;
- AWS SigV4 canonical requests, credential scope, signed-header selection, and
  key-derivation sequencing;
- Stripe signature-header parsing, timestamp tolerance, secret rotation, event
  deduplication, and tenant checks;
- TLS server-name selection, trust-policy selection, deadlines, cancellation,
  error classification, and the prohibition on insecure product defaults;
- secret provenance, unprintability, cleanup, effects, audit records, and
  redaction.

Do not split the TLS state machine across Gust and the provider. Certificate
chain construction, hostname verification, protocol negotiation, cipher-suite
selection, record protection, alerts, session resumption, and key schedule stay
inside the mature TLS library. Gust configures and observes the bounded
connection resource.

## TLS and resource rules

A TLS connection wraps one owned socket and is itself a move-only linear
resource. Closing it closes or deterministically returns ownership of the
underlying socket according to one documented rule; it cannot leak a native
`SSL_CTX`, `SSL`, certificate, or provider pointer.

The product path must:

- verify certificate chains and the requested server name;
- use explicit trust roots and a declared deployment trust policy;
- reject unsupported protocol versions, algorithms, malformed certificates,
  and invalid signatures;
- apply connection, handshake, read, and write deadlines;
- preserve cancellation and exactly-once cleanup;
- keep secrets, session material, certificate internals, and provider error
  stacks out of application logs;
- expose peer identity and negotiated metadata only through bounded safe values.

Development-only insecure trust modes, if they exist at all, require an
explicit non-production configuration and must be impossible to select through
ordinary application input.

## Deferred algorithms

Do not expose AES-GCM, ChaCha20-Poly1305, RSA, Ed25519, ECDSA, HKDF, X25519, raw
key parsing, or arbitrary digest/cipher selection merely because the provider
contains them. TLS may use those algorithms internally without making them
application APIs.

Add a primitive only for a concrete owned use case with:

- a misuse-resistant typed operation rather than a bag of byte slices;
- fixed permitted algorithm and parameter choices;
- key generation/import, validation, storage, rotation, and destruction rules;
- nonce generation and uniqueness policy for AEAD;
- public/private and signing/verification role separation;
- malformed-key, wrong-algorithm, cross-tenant, and side-channel review;
- standards vectors and cross-provider conformance evidence.

In particular, a public `aes_gcm_encrypt(key, nonce, bytes)` is not an acceptable
first API: nonce reuse can destroy GCM's security, so the safe abstraction must
own nonce construction or enforce uniqueness structurally.

## Errors, secrets, and memory

Provider failures become a small stable taxonomy such as unavailable,
unsupported, invalid input, authentication failed, certificate rejected,
deadline exceeded, peer closed, and internal provider failure. Native error
queues are diagnostic inputs for the runtime, not strings returned to
applications.

Secret inputs and derived material must:

- use opaque secret-bearing values where the type system can enforce them;
- never be formatted, serialized, compared normally, or copied into ordinary
  diagnostics;
- have explicit lifetime and cleanup ownership;
- avoid unnecessary arena copies;
- use the provider/runtime constant-time operation for secret comparisons;
- be cleared when the memory representation and optimizer boundary make that
  guarantee meaningful.

`secure_clear` is not a magic guarantee: copies, immutable language values,
compiler optimizations, swap, core dumps, and provider-internal state all affect
what can actually be erased. The implementation must document the precise
memory boundary it protects rather than claiming universal zeroization.

## Conformance and validation

The provider-neutral corpus should contain:

- RFC protocol vectors for SCRAM and each consumer state machine;
- [NIST CAVP][nist-cavp] vectors for SHA-256, HMAC-SHA256, PBKDF2 and any later
  admitted primitive;
- provider known-answer, malformed-input, boundary-length, aliasing, and
  cleanup tests;
- differential results across the pinned OpenSSL provider and any proposed
  replacement;
- TLS interoperability, invalid-chain, wrong-host, expiry, revocation-policy,
  truncation, timeout, cancellation, and abrupt-close tests;
- secret-redaction and native-error-stack containment tests;
- exact provider version, build configuration, target and provenance evidence.

Passing public test vectors is correctness evidence, not proof of production
security or FIPS validation. A FIPS claim additionally depends on the exact
validated module, build, operating environment, approved algorithm/parameter
use, security policy, and operational controls. AWS-LC, for example, documents
runtime service-indicator checks for approved use; merely linking a FIPS-capable
library is not the claim.

## Sequencing

1. **Contract and ownership decision.** Resolve native provider, FFI/layout,
   runtime symbol, resource, effect, secret-memory, and guarantee-ledger owners.
2. **OpenSSL shim.** Add the smallest C boundary for randomness, SHA-256, HMAC,
   PBKDF2, constant-time comparison, cleanup, and provider diagnostics.
3. **Offline conformance.** Run standards vectors, malformed inputs, bounds,
   redaction, cleanup, and differential tests before any network consumer.
4. **TLS resource.** Integrate the provider with the owned socket, deadlines,
   cancellation, certificate/hostname verification, and exactly-once cleanup.
5. **First consumers.** PostgreSQL SCRAM, SigV4, Stripe webhook verification,
   then S3/Stripe HTTPS clients use the same checked contract.
6. **Alternative provider.** Add AWS-LC LTS or another provider only after it
   passes the complete corpus and has an explicit release/security policy.
7. **Public crypto APIs.** Consider additional application-facing primitives
   only after real use cases demonstrate that the internal boundary is
   insufficient.

This ordering lets Gust own the safe semantics without making cryptographic
implementation an adoption prerequisite or pretending that a handwritten
primitive inherits the platform's memory-safety guarantees.

[openssl-evp]: https://docs.openssl.org/master/man7/evp/
[openssl-releases]: https://mirror.openssl-library.org/policies/releasestrat/index.html
[aws-lc]: https://github.com/aws/aws-lc
[aws-lc-versioning]: https://github.com/aws/aws-lc/blob/main/VERSIONING.md
[boringssl]: https://github.com/google/boringssl/blob/main/README.md
[ring]: https://github.com/briansmith/ring
[nist-cavp]: https://csrc.nist.gov/Projects/Cryptographic-Algorithm-Validation-Program
