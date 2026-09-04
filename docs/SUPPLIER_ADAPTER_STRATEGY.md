# Reference supplier adapters and vendor handoff

**Status:** proposed adoption strategy, recorded 2026-08-27 and updated
2026-09-01. This note does not
activate supplier implementation work, assign an active roadmap lane, admit a
supplier, authorize a dependency, or promise certification. `docs/VISION.md`
Part XVI remains authoritative for supplier governance.

## Proposal

Gust should not wait for external vendors to build the integrations required to
make the platform useful. Before adoption gives Amazon, Stripe, or another
supplier a reason to invest, Gust should build and maintain production-grade
**reference supplier adapters** itself.

Those adapters implement ordinary, versioned Gust capability contracts. They
are not compiler special cases, privileged SDK imports, or public application
APIs shaped around one supplier. Applications depend on Gust-owned capabilities
such as `storage` and `payments`; a deployment selects an approved adapter behind
that boundary.

If adoption later justifies a vendor-maintained implementation, ownership can
move without changing application architecture:

1. Gust publishes and maintains the initial reference adapter.
2. Gust publishes the capability contract and supplier-neutral conformance
   corpus.
3. Community implementations may target the same contract.
4. A supplier may take over or publish an official implementation.
5. Every implementation passes the same conformance, containment, reliability,
   and data-egress checks before admission.
6. Gust continues to own the application-facing contract and certification
   rules; the supplier may own its adapter's release maintenance.

Until ownership actually changes, documentation must say **Gust-maintained
reference implementation**, not "official Amazon" or "official Stripe". An
implementation being compatible with a supplier does not imply that supplier's
endorsement.

## Boundary that must remain stable

The capability contract is the portability boundary:

```text
application
  -> Gust capability (`storage.put`, `payments.refund`, ...)
  -> versioned supplier-neutral contract
  -> selected adapter
  -> external supplier API
```

Gust owns:

- the application-facing operation names and types;
- resource ownership, memory lifetimes, effects, and tenant isolation;
- logical secret names and the prohibition on exposing credentials;
- deadlines, cancellation, retry and idempotency requirements;
- the supplier-neutral error taxonomy and observability fields;
- the data-egress declaration and supplier-specific request view;
- the conformance corpus, admission criteria, compatibility window, and
  revocation mechanism.

The adapter owns:

- protocol framing, authentication, signing, and supplier endpoint behavior;
- translation between the Gust contract and a pinned supplier API version;
- supplier-specific error and rate-limit interpretation;
- compatibility work when the supplier changes its API;
- evidence that it satisfies the shared conformance corpus.

Supplier-specific configuration may exist at the deployment boundary, but it
must not leak supplier request types or credentials into ordinary application
code. An adapter written by Gust must receive no authority unavailable to a
future vendor- or community-maintained adapter.

## Deployment providers are not application capabilities

The deployment-provider boundary and the supplier-adapter boundary are related,
but they are not interchangeable:

```text
application code
  -> capability contract
  -> selected supplier adapter
  -> supplier API

release manifest
  -> resource and provider bindings
  -> deployment-provider adapter
  -> infrastructure control plane
```

A supplier adapter implements application behavior such as object storage or
payments within the authority granted to the application. A deployment adapter
is an operator control-plane component: it provisions or binds compute,
databases, secret references, domains, and observability needed to run a
release. A cloud platform may host several supplier adapters, but that does not
make the cloud itself one giant application-visible capability.

This distinction preserves the capability system's least-authority model. It
also permits Railway, Render, Northflank, Fly, a bare VM, or a future Gust
control plane to satisfy the same deployment contract without changing
application source or supplier capability contracts. Provider-specific
resource identifiers and credentials remain in deployment state; capability
types and supplier-neutral application behavior remain in the application
contract.

The compiler-owned Application Model may place all of these relationships in
one graph, but it must retain their kinds:

- a **logical resource instance** such as an orders database has identity,
  schema, state, migration, backup, retention and deletion policy;
- an **application capability** such as payments or storage grants a bounded
  set of typed operations and effects;
- a **supplier adapter** implements that capability against a pinned external
  protocol;
- a **deployment-provider adapter** provisions or binds the infrastructure and
  runtime configuration needed by a release.

The capability declaration is the authority ceiling. Proven operation-level
use may justify narrower generated credentials, but an incomplete call graph,
dynamic behavior, migration or recovery path must produce a conservative
binding or a deployment refusal. Provider convenience never justifies silently
widening the declared capability, and optimizer reachability is not an
authorization policy.

## Reference hierarchy

Do not transliterate a vendor SDK wholesale. Use three kinds of reference, in
this order:

1. The supplier's protocol and API documentation is normative.
2. A focused current upstream implementation is a behavioral oracle for hard
   edge cases and test vectors.
3. Gust defines its own capability, effect, resource, memory, and error model.

Generated models, reflection systems, dependency injection, general retry
frameworks, telemetry defaults, compatibility shims, and language-specific
ergonomics from an upstream SDK are not automatically part of a Gust adapter.
The PostgreSQL version of this rule is recorded in
`docs/POSTGRES_DRIVER_ARCHITECTURE.md`.

The shared provider choice, stable internal contract, initial OpenSSL boundary,
TLS ownership, conformance requirements, and deferred algorithm policy are
specified in `docs/CRYPTO_PROVIDER_ARCHITECTURE.md`. Supplier adapters consume
that boundary; they do not choose or directly bind their own crypto library.

Both adapters also consume the one Gust outbound HTTP client described in
`docs/HTTP_RPC_ARCHITECTURE.md`. Go's `net/http.Transport` is the focused worked
reference for pools, retries, redirects, proxies, TLS, deadlines, and body
ownership. An adapter must not embed its own transport or bypass Gust's egress,
redirect-credential, resource, cancellation, body-bound, and redaction policy.
The complete adjacent selection is indexed in
`docs/FULL_STACK_REFERENCE_MAP.md`.

## AWS S3-compatible storage reference adapter

### Sources of authority

- AWS's [Signature Version 4 documentation][aws-sigv4] is normative for
  canonical requests, credential scope, signing-key derivation, signed headers,
  query signing, session tokens, and payload hashes.
- The current [AWS SDK for Go v2][aws-go-v2] signer and S3 presigner are worked
  references and behavioral oracles.
- The deprecated Go v1 `aws/signer/v4` package must not be selected as the
  primary reference for new work.

The generic SigV4 signer is not the whole S3 adapter. S3 also has
service-specific endpoint resolution, virtual-hosted and path-style addressing,
URI escaping behavior, region selection, payload-hash rules, and presigning
behavior. The reference corpus must cover the complete request as observed by
the service, not merely compare one HMAC result.

### Gust-facing shape

Ordinary applications should receive bounded operations such as object put,
get, delete, metadata read, and presigned upload/download. They should not
receive raw AWS requests, signing keys, bucket-wide credentials, or unrestricted
network authority.

A sensible first slice is:

- presigned `GET` for one tenant-scoped object;
- presigned `PUT` for one tenant-scoped object;
- direct put/get/delete through the storage capability;
- explicit content length, content type, checksum, and expiry constraints;
- AWS S3 plus a deliberately named S3-compatible provider test matrix.

Defer multipart upload, copy, listing, object ACLs, event notifications, and the
full AWS SDK surface until concrete application requirements justify them.

A presigned URL is bearer authority. Keep its lifetime short, bind it to the
minimum method and object scope, constrain upload properties where the provider
supports doing so, and never emit the full URL or signature into ordinary logs.
Cryptographic primitives and constant-time operations come from an audited
runtime boundary rather than from a handwritten Gust implementation.

"S3-compatible" must name a tested profile. AWS S3, MinIO, R2, or another
provider is compatible only for the operations and endpoint modes exercised by
the shared corpus; the label must not silently promise the entire S3 API.

## Stripe payments reference adapter

### Sources of authority

- Stripe's current API documentation and [OpenAPI specification][stripe-openapi]
  are normative for endpoints, fields, and versioned schemas.
- [`stripe-go`][stripe-go] is a behavioral oracle for request encoding,
  headers, error translation, API-version handling, request IDs, idempotency,
  and difficult response cases. Its entire generated public API is not the Gust
  contract.
- [`stripe-go/webhook`][stripe-go-webhook] and Stripe's [webhook signature
  guidance][stripe-webhooks] are the focused references for webhook
  authentication.

### Gust-facing shape

Applications should call business-level operations such as creating a payment
intent, confirming or capturing it, refunding it, and handling an authenticated
payment event. They should not construct arbitrary Stripe HTTP requests or
depend directly on generated Stripe object types.

The adapter pins an explicit Stripe API version. Every mutating operation uses
a Gust-owned idempotency key tied to the tenant and logical operation. A retry
must retain that key; generating a new key during recovery could repeat an
irreversible effect. Stripe's [idempotent request contract][stripe-idempotency]
is part of the reference evidence, while Gust's stricter capability policy
remains authoritative for applications.

Webhook handling must:

- preserve the exact raw request bytes until authentication succeeds;
- verify the timestamp and all supported current signatures using constant-time
  comparison;
- accept overlapping signing secrets for rotation through the protocol's
  multiple-signature form;
- provide no ordinary "ignore timestamp tolerance" path;
- parse the authenticated envelope according to the pinned event/API version;
- validate account, livemode, tenant context, and expected event family;
- deduplicate the event identifier and make downstream handling idempotent;
- acknowledge promptly and move durable work to the owned job boundary;
- tolerate duplicate and out-of-order delivery.

Snapshot and thin event forms should share authentication but use explicit,
versioned parsing paths. Authenticating a webhook proves its Stripe origin; it
does not prove the business operation is valid, belongs to the expected tenant,
or has not already been processed.

The adapter must redact API keys, client secrets, webhook secrets, signatures,
and sensitive payload fields from logs. It should retain safe operational
identifiers such as Stripe request IDs and Gust correlation IDs where policy
allows.

Both the S3 and Stripe reference adapters depend on the same runtime-owned
crypto/TLS provider. Neither adapter may carry a private OpenSSL, BoringSSL,
`ring`, or handwritten cryptographic implementation that bypasses the shared
provider contract and its conformance corpus.

## Transactional email and later SMS

The first Gust-maintained transactional-email adapter targets [Amazon SES
v2][ses-v2]. The AWS SDK for Go v2 [`sesv2` service package][aws-go-v2-ses]
is the primary worked implementation reference. This is the smallest coherent
choice because the S3 adapter already requires the same AWS configuration,
SigV4, HTTP, crypto, retry, and error evidence.

Applications receive a provider-neutral `email` capability with bounded typed
recipients, subject, text/HTML alternatives, attachments, templates, tags, and
idempotency/correlation metadata. They do not receive SES identities,
configuration sets, raw AWS requests, or unrestricted MIME construction.
Provider events for delivery, bounce, complaint, and rejection enter through an
authenticated, deduplicated supplier-event path and cannot silently mutate
application state in the HTTP callback.

SMS is deferred until a concrete application needs it. At that point [Twilio
Messaging][twilio-messaging] and the official [Twilio Go helper][twilio-go] are
the primary references for REST requests, authentication, status callbacks,
inbound messages, pagination, and request-signature validation. SMS needs its
own capability and consent/regional/delivery policy; it is not email with a
phone-number field.

## Application upload paths

Uploads are an application/storage boundary, not merely an S3 method:

1. [RFC 7578][rfc-7578] is normative for `multipart/form-data`; Go's
   [`mime/multipart`][go-multipart] is the worked reference for bounded
   streaming parsing, part headers, temporary storage, and cleanup.
2. Direct browser-to-object-storage uploads use the existing AWS Go v2 S3
   presigner reference. A Gust server grants one short-lived, tenant/object-
   scoped upload with explicit method, size, type, checksum, and expiry policy.
3. Resumable upload is later work. The [tus 1.0 protocol][tus] is normative and
   [`tusd`][tusd] is the server reference for offsets, interruption, resumption,
   expiration, locking, completion, and S3-backed storage.

Gust owns the upload capability, authorization, object identity, temporary-file
or object resource, limits, checksums, cleanup of abandoned work, optional
scanning hooks, and the explicit transition to a completed object. A presigned
URL or tus upload identifier is scoped bearer authority and must not enter
ordinary logs.

## Conformance and ownership transfer

The conformance corpus is the durable asset. At minimum it should cover:

- contract schema and version negotiation;
- success responses and the complete declared error taxonomy;
- timeouts, cancellation, rate limits, retry eligibility, and idempotency;
- malformed, truncated, oversized, duplicated, and reordered inputs;
- secret redaction and minimum data-egress declarations;
- tenant separation and scoped credentials;
- deterministic offline protocol/signature fixtures;
- live disposable-account interoperability tests where supplier terms permit;
- compatibility across every provider or API version advertised as supported.

Conformance and trust remain separate decisions. Passing the corpus demonstrates
that an implementation follows the declared contract; it does not decide that a
supplier is commercially or operationally trustworthy. Supplier admission,
terms, liability, region policy, credential issuance, and revocation remain
human decisions under `docs/VISION.md` Part XVI.

Vendor handoff is appropriate only when the replacement:

- implements the same versioned capability contract without widening authority;
- passes the same corpus in an environment Gust can independently verify;
- declares its release, security-response, deprecation, and compatibility
  policy;
- preserves migration and rollback from the Gust-maintained adapter;
- does not require applications to import its SDK or abandon portable types;
- can be revoked or replaced without redesigning the application.

This lets Gust provide a credible full stack before vendors care, while making
later vendor participation an ownership and maintenance change rather than an
architectural rewrite.

[aws-sigv4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html
[aws-go-v2]: https://github.com/aws/aws-sdk-go-v2
[stripe-openapi]: https://github.com/stripe/openapi
[stripe-go]: https://github.com/stripe/stripe-go
[stripe-go-webhook]: https://github.com/stripe/stripe-go/blob/master/webhook/client.go
[stripe-webhooks]: https://docs.stripe.com/webhooks/signature
[stripe-idempotency]: https://docs.stripe.com/api/idempotent_requests
[ses-v2]: https://docs.aws.amazon.com/ses/latest/APIReference-V2/Welcome.html
[aws-go-v2-ses]: https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/service/sesv2
[twilio-messaging]: https://www.twilio.com/docs/messaging/api
[twilio-go]: https://github.com/twilio/twilio-go
[rfc-7578]: https://www.rfc-editor.org/rfc/rfc7578
[go-multipart]: https://pkg.go.dev/mime/multipart
[tus]: https://tus.io/protocols/resumable-upload
[tusd]: https://github.com/tus/tusd
