# Full-stack upstream reference map

**Status:** proposed reference map, recorded 2026-08-27 and updated 2026-09-01.
This note selects
standards, implementation references, and conformance corpora for future work.
It does not activate a roadmap lane, authorize dependencies or runtime symbols,
settle shared semantic decisions, or make any referenced project a Gust product
dependency. The relevant architecture document and active roadmap remain
authoritative for scope and sequencing.

## Rule

Use an upstream project for the narrow thing it demonstrates well:

1. a protocol or standards document is normative where one exists;
2. a mature implementation is a worked behavioral reference and differential
   oracle;
3. an independent corpus supplies adversarial and compatibility evidence;
4. Gust owns its public types, effects, capabilities, resources, errors,
   generated code, and product policy.

Do not transliterate an entire framework. Generated models, reflection,
dependency injection, package ecosystems, configuration surfaces, runtime
authority, and language-specific ergonomics do not cross into Gust merely
because the focused upstream component contains them.

## Prototype reference map

| Boundary | Normative authority | Primary worked reference | Independent evidence | Gust owns |
| --- | --- | --- | --- | --- |
| JSON serialization | [RFC 8259][rfc-8259] | [Serde JSON][serde-json] for strongly typed decoding/encoding and writer-oriented output | [JSONTestSuite][json-test-suite] plus Gust-generated round trips | monomorphic codecs, admitted type shapes, bounds, duplicate/unknown-field policy, errors, arena placement, canonical contract hashing |
| HTTP server | RFC 9110/9112 | h11 state machine; Go `net/http` server lifecycle | llhttp malformed-input/differential corpus | strict parser profile, socket/task ownership, limits, deadlines, routing, request context |
| Outbound HTTP client | RFC 9110/9112, URL/TLS standards, supplier protocol | Go [`net/http.Transport`][go-http-transport] for connection reuse, pooling, retries, redirects, proxies, TLS, deadlines, and body ownership | disposable origin/proxy servers and supplier fixtures | typed request capability, egress policy, DNS/TLS resources, retry eligibility, redirect credential policy, bounded bodies, redaction |
| Typed PostgreSQL wire | PostgreSQL protocol | pgx `pgproto3` and `pgconn` | rust-postgres and optional temporary libpq oracle | connection resource, effects, memory, state, errors, generated value codecs |
| Typed SQL derivation | PostgreSQL grammar/catalog and Gust schema model | [sqlc][sqlc] for SQL-to-generated typed functions | disposable PostgreSQL and compiler-generated positive/negative queries | query surface, result/effect/scope triple derivation, arena/result types, tenant obligations |
| Schema migrations | PostgreSQL DDL and Gust compatibility policy | [Flyway][flyway] for ordered execution, history, and checksums; [Atlas][atlas] as a separate design-time diff, lint, and drift tool | fresh-install, every-supported-upgrade, checksum-tamper, unsafe-plan, and drift tests | explicit reviewed migration files, destructive approval, expand/contract, backfills, tenant rollout, supported schema range |
| Browser Wasm and DOM | WebAssembly/Web IDL/DOM/HTML standards | `wasm-bindgen`, `web-sys`, and Lit | Web Platform Tests and real browsers | host manifest, typed bridge, browser capabilities, template compiler, SAM actions, handle lifetime |
| Browser end-to-end testing | browser standards and the accessibility standards below | [Playwright][playwright] for real-browser automation, network interception, traces, and ARIA snapshots | Chromium, Firefox, WebKit, [axe-core][axe-core], and selected Web Platform Tests | deterministic fixtures, full-stack scenarios, accessibility assertions, supported-browser policy, trace retention |
| Typed routing | [WHATWG URL][whatwg-url] and [URLPattern][url-pattern] | [TanStack Router][tanstack-router] for typed route identity, parameters, search validation, loading, preloading, and code-split boundaries | WHATWG/Web Platform URL tests plus generated link/match round trips | explicit route declarations, authorization metadata, canonical parameters, compiler-managed loading and splitting |
| Forms and accessibility | HTML form/constraint-validation semantics, [WCAG][wcag], and WAI-ARIA | [Conform][conform] for schema-derived, progressively enhanced server/client forms | Playwright ARIA snapshots, [axe-core][axe-core], keyboard/focus tests, and manual audits | typed fields, RPC/schema agreement, errors, focus policy, safe markup, server authority, progressive enhancement |
| Frontend query cache | Gust RPC/SAM contracts and browser cancellation rules | TanStack [`query-core`][tanstack-query] for query identity, stale/fresh lifecycle, in-flight deduplication, cancellation, retries, invalidation, and garbage collection | deterministic race, retry, cancellation, acknowledgement-order, rollback, reconnect, and tenant-isolation fixtures | typed query identity, tenant/contract-version keys, pending SAM action journal, retry authority, reconciliation, cache bounds |
| Asset graph, scoped CSS, and development server | HTML/CSS/JavaScript modules, source maps, CSP, and browser fetch/cache standards | [Vite][vite] for the development module graph and invalidation; [esbuild][esbuild] for production graph/output behavior; [Lightning CSS][lightning-css] for CSS transformation; [Vue scoped CSS][vue-scoped-css] for the scope-attribute technique | cross-browser load/reload tests, deterministic build manifests, CSS parser fixtures, CSP/integrity tests | compiler-owned asset graph, stable scope identity, emitted Wasm/bridge/assets, full-reload/HMR policy, deployment manifest |
| Typed RPC | Gust service manifest and declared wire version | Connect for HTTP-native RPC; tRPC for ergonomics | Connect/gRPC conformance after a compatible adapter exists | service declarations, codecs, dispatcher, client stubs, Query/Mutation rules, auth context, errors, contract hash |
| Streaming RPC and realtime subscriptions | Connect/gRPC protocol rules, WHATWG EventSource, RFC 6455, and the WHATWG WebSocket API | Connect for typed stream envelopes; [Phoenix Channels][phoenix-channels] for topic/join/heartbeat/reconnect behavior; `wsproto` for a small Sans-I/O WebSocket state machine | Connect conformance, browser SSE fixtures, [Autobahn Testsuite][autobahn-testsuite], and disconnect/resume/overflow tests | Stream versus Subscription semantics, typed cursors, ordering, bounded backpressure, auth/tenant context, transport choice, durable storage boundary |
| Authentication | [WebAuthn][webauthn] and [OpenID Connect Core][oidc-core] | no general application framework is authoritative; use focused conforming implementations only as ceremony and interoperability oracles | WebAuthn Web Platform Tests, OIDC provider interoperability, replay/session fixtures | identity, membership, authorization, challenges, account linking, recovery, audit, tenant context |
| Sessions | browser cookie standards, HTTP security rules, Gust identity policy | focused mature session implementations may inform rotation/revocation, but no framework session model is selected | expiry, rotation, theft/replay, fixation, revocation, device, tenant, and rolling-upgrade tests | session schema, device binding, refresh rotation, CSRF, revocation, capability context, audit |
| Cryptography and TLS | algorithm/TLS standards | pinned OpenSSL 3 through a narrow Gust shim | standards vectors and later cross-provider tests | safe provider contract, policy, secrets, resources, redaction, reproducible provider selection |
| Durable jobs | Gust's typed job and tenant/effect contract | [Oban][oban] for PostgreSQL-backed transactional enqueue, retries, uniqueness, schedules, recovery, history, and graceful shutdown | crash/restart, database outage, duplicate delivery, clock, cancellation, and multi-worker tests | typed job schema, effects, tenant context, idempotency declarations, outbox, fairness, workflow semantics |
| Durable workflows | Gust's typed workflow and event-history contract | [Temporal Go SDK][temporal-go] and Temporal server semantics for deterministic replay, activities, signals, timers, cancellation, child workflows, and versioning | replay of pinned histories, worker-version overlap, crash/restart, duplicate-event, timer, signal, and cancellation tests | typed workflow state, storage schema, tenancy/effects, command/history separation, compatibility policy, operational scope |
| Observability | [OpenTelemetry specification][otel-spec] and W3C trace context where applicable | official OTel SDKs and Collector behavior as interoperability references | OTLP receiver/collector tests and cross-process propagation fixtures | compiler/runtime instrumentation points, capability-safe fields, tenant scoping, redaction, execution traces, sampling policy |
| S3 and Stripe adapters | supplier protocols and pinned API versions | AWS SDK for Go v2 and Stripe Go focused packages | offline signing/webhook fixtures and disposable supplier tests | supplier-neutral capabilities, effects, tenancy, errors, data egress, conformance, replaceability |
| Transactional email and SMS | pinned supplier APIs, email/MIME standards, and authenticated webhook contracts | AWS SDK for Go v2 `sesv2` for the first Gust-maintained email adapter; Twilio's Go helper and Messaging API when SMS is justified | offline request/webhook fixtures, disposable supplier accounts, bounce/complaint/status, retry, and idempotency tests | `email`/`messaging` capabilities, templates and payload bounds, consent policy, tenancy, errors, redaction, provider replacement |
| Uploads | [RFC 7578][rfc-7578], HTTP semantics, and supplier storage contracts | Go [`mime/multipart`][go-multipart] for bounded streaming multipart; AWS SDK for Go v2 for direct-to-S3 presigning; [tusd][tusd] later for [tus][tus] resumability | malformed multipart corpus, checksum/size/type tests, interrupted/resumed upload tests, S3-compatible matrix | upload capability, temporary-file/object resources, tenant/object scope, limits, checksums, cleanup, scanning hooks, completion policy |
| Configuration and secrets | deployment manifest, environment/process rules, and selected provider protocols | [.NET Configuration and Options][dotnet-options] for layering, typed validation, snapshots, and reload notifications; [OpenBao][openbao] for provider-backed leases, renewal, rotation, and revocation | precedence, missing/invalid value, reload race, expiry, renewal, revocation, redaction, and provider-failure tests | typed schema, deterministic precedence, immutable snapshots, secret handles, capability/effect checks, audit and provider neutrality |
| Application model and deployment providers | Gust typed capability/resource authority and release contract | [Encore][encore-application-model] for the derived application model; [Nitric][nitric-providers] for provider plugins and mismatch; [Lakebed][lakebed-docs] for constrained agent workflow and inspection UX | local plus two independent provider implementations, unsupported-resource refusal, least-authority diffs, control-plane outage, drift and migration tests | compiler-owned Application Model projection, operator Environment Binding, resolved ReleasePlan, authority ceilings, conformance profiles, provider visibility and runtime independence |
| Deployment artifact and rollout | [OCI Image Format][oci-image] and [OCI Distribution][oci-distribution] | [BuildKit][buildkit] for repeatable cache-efficient artifact construction; Kubernetes probe and Deployment-controller behavior for health, drain, and rolling updates | OCI validation, disposable-runtime smoke tests, signal/drain tests, and old/new-version rollout matrices | immutable release manifest, capability/config binding, health semantics, graceful drain, compatibility gates, rollback policy, orchestrator neutrality |

## JSON serialization

RFC 8259 defines accepted JSON syntax and interoperability constraints. Serde
JSON is the worked reference for converting strongly typed values directly to
and from readers/writers without requiring every call to build a generic dynamic
tree. JSONTestSuite supplies must-accept, must-reject, ambiguous, and
transformation cases that catch parser disagreements and crashes.

Gust does not import Serde's trait, derive, generic `Value`, Cargo, or allocator
model. The compiler generates one bounded codec per admitted monomorphic RPC,
job, message, supplier, configuration, or trace type. Before code exists, the
contract must decide:

- integer ranges and the absence or representation of non-finite numbers;
- UTF-8, escape, surrogate, control-character, and nesting behavior;
- duplicate object key policy;
- unknown and missing field policy;
- deterministic field order and canonical bytes where hashing requires them;
- maximum depth, string, collection, object, and total input sizes;
- allocation arena and cleanup on partial decode;
- stable path-aware errors that never echo secrets by default.

Canonical contract hashing must hash a canonical schema/manifest, not whatever
object-key order one JSON writer happened to emit.

## Outbound HTTP

The strict HTTP state machine in `docs/HTTP_RPC_ARCHITECTURE.md` should be
symmetric enough to support clients and servers, but the client runtime has
additional authority and lifecycle problems. Go's `net/http.Transport` is the
primary worked reference for:

- reusable concurrent transports and per-origin connection pools;
- dial, TLS handshake, response-header, body, idle, and total deadlines;
- request-body ownership, rewindability, cancellation, and response-body close;
- retry only when both the failure point and operation idempotency permit it;
- redirect policy and stripping credentials across authority boundaries;
- proxy selection and CONNECT behavior;
- keep-alive reuse, idle eviction, pool bounds, and graceful shutdown.

Gust must be stricter than a general application client where capability and
supplier policy require it. Applications do not receive unrestricted URLs or
raw headers merely because the transport can send them. S3 and Stripe adapters
construct bounded requests behind their declared capabilities, sign the exact
bytes sent, restrict destinations and redirects, propagate deadlines, drain or
close bodies deterministically, and redact credentials and signed material.

## Frontend query cache and optimistic reconciliation

TanStack `query-core`, not its React hooks or component conventions, is the
primary behavioral reference. Its useful surface is the transport-independent
query lifecycle: canonical query identity, fresh/stale state, one in-flight
request per key, cancellation, retry eligibility, invalidation, background
refetch, observation, and bounded garbage collection.

Gust's first cache is a typed **query-result cache**, not a normalized entity
graph. Its key includes procedure identity, canonical typed input, resolved
tenant/workspace context, and the applicable contract version. Entity
normalization would introduce identity, merge, partial-object, and ownership
rules that Slice 0 does not need and TanStack Query does not supply.

TanStack informs the race cases; SAM owns optimistic semantics. The authoritative
cache value remains the last confirmed server result. A mutation appends a
typed action to the pending journal in `docs/VISION.md` §38.1, presentation folds
confirmed data plus pending actions, acknowledgement replaces confirmed data
and removes the matching action, and rejection removes it and refolds. This
avoids arbitrary user callbacks rewriting shared cache entries and scales to
out-of-order acknowledgements without retaining ad hoc inverse snapshots.

## Browser assets, scoped CSS, and development server

Use Vite as the primary development-behavior reference: a module/asset graph,
on-demand transforms, dependency-aware invalidation, actionable diagnostics,
and an explicit fall back from a rejected hot update to full-page reload. Gust
does not adopt Vite's JavaScript plugin ecosystem or make Node part of the
application runtime.

Use esbuild as the focused production graph/output reference for entry points,
code splitting, tree shaking, content hashes, source maps, asset naming, and a
machine-readable output manifest. Use Lightning CSS for standards-aware parsing,
target transforms, bundling, and minification. Vue's scoped-CSS transformation
is the worked reference for stamping a stable compiler-owned scope attribute on
generated DOM and rewriting selectors against it; Vue components and runtime
are not part of the design.

The first Wasm prototype uses deterministic content-addressed output and full
page reload. State-preserving Wasm HMR is deferred until Gust has a compatible
model-layout and resource-lifetime contract; keeping stale Wasm state across a
new module is not a development convenience the bridge may guess through.

## Streaming RPC, subscriptions, SSE, and WebSockets

No single upstream owns all four layers. Connect is the typed RPC framing and
error reference; WHATWG EventSource is the first browser server-to-client
subscription transport; RFC 6455 and the WHATWG API govern WebSockets; Phoenix
Channels is the worked application-protocol reference for multiplexed topics,
join/leave authorization, request references, heartbeats, reconnects, and
draining; and `wsproto` plus Autobahn supply a small state-machine shape and
protocol evidence.

Gust should ship realtime incrementally:

1. unary RPC remains the first full-stack slice;
2. SSE carries the first typed server-to-browser subscription, including an
   explicit resumable cursor rather than relying only on transport connection
   state;
3. Connect-style server streams cover typed ordered stream envelopes where
   fetch/proxy support is suitable;
4. WebSockets appear only for genuine bidirectional interaction and multiplex
   several typed topics over one connection;
5. client-streaming and bidirectional RPC use the gRPC/Connect model only after
   cancellation, flow control, bounds, and browser transport are specified.

A live transport is not durable storage. Best-effort Streams may end on
disconnect; durable Subscriptions resume from a versioned application cursor
backed by a database changefeed or event log and provide at-least-once delivery.
Every transport has a bounded outbound queue and an explicit overflow policy;
none may silently turn a slow client into unbounded process memory.

## Typed queries and migrations

`sqlc` is the primary worked reference for treating SQL as compiler input and
generating typed functions rather than an untyped runtime string API. Gust's
derivation is broader: one query walk must produce the result type, effect
requirement, and tenant-scope obligation described by `docs/VISION.md` §55.1.
`sqlc` informs parsing, parameter/result mapping, schema/catalog integration,
and generated function shape; it does not define Gust authority or scoping.

Migration tooling is deliberately split. Flyway is the operational reference
for applying explicit ordered files and recording version, checksum, time, and
outcome in a schema-history table. Atlas is the separate design-time reference
for inspecting schemas, generating a proposed SQL diff, linting unsafe changes,
and detecting drift. Atlas output is review input; it never gains authority to
silently apply a generated production plan.

The selection must be made against Gust's existing decision: explicit reviewed
up/down migration files, a central ordered manifest, destructive approval,
expand-and-contract deployment, resumable backfills, bounded tenant rollout,
and supported schema-version ranges. A convenient upstream workflow does not
override those commitments.

## Authentication and sessions

WebAuthn and OpenID Connect are protocol authorities, not inspiration. Gust
should not copy a web framework's authentication middleware, database model, or
ambient request context and call it an identity architecture.

WebAuthn governs passkey registration/authentication ceremonies, relying-party
and origin checks, challenges, credential identifiers, authenticator data,
signature verification, counters, user verification, and attestation policy.
OIDC Core governs authorization responses, issuer/audience/nonce/state checks,
token validation, key rotation, claims, and provider interoperability.

Gust still owns account identity, memberships, tenant selection, authorization,
session/device records, refresh rotation, revocation, recovery, linking,
impersonation, audit, and the immutable capability context injected into a
request. External identity proves an identity claim; it does not grant Gust
authorization.

## Durable jobs

Oban is the primary worked reference because it makes PostgreSQL the durable
queue and demonstrates the operational details most toy queues omit:
transactional enqueue with application changes, at-least-once delivery,
uniqueness, retries/backoff, scheduling, priorities, cancellation, execution
history, orphan recovery, queue isolation, database outage behavior, and
graceful shutdown.

Gust does not import Elixir processes, Ecto changesets, plugin APIs, or Oban's
public schema as application semantics. Gust jobs remain typed server functions
with serializable owned inputs, immutable tenant context, declared effects,
deadlines, explicit retry/idempotency policy, database outbox integration, and
compiler-generated conformance checks.

## Durable workflows

Temporal's Go SDK and server model are the primary worked references once a
process must remain alive across timers, external events, approvals, supplier
responses, or worker replacement. The useful boundary is the durable event
history and deterministic command replay: workflow code decides; activities
perform fallible external effects; signals/events resume waiting state; version
markers and worker compatibility keep old histories replayable.

This is not a proposal to port or require the Temporal service. Ordinary
background work stays in the simpler Oban-style PostgreSQL job runtime. Gust
introduces a workflow runtime only after an application needs long-lived event
waiting, and then owns its typed state/history representation, PostgreSQL
storage, tenant/effect rules, deployment compatibility, and bounded operational
profile. Pinned-history replay is the central conformance artifact.

## Browser testing, routing, and forms

Playwright is the external E2E runner, not an application dependency. It runs
the same generated Gust application in supported Chromium, Firefox, and WebKit,
captures traces and network behavior, and asserts the accessibility tree.
`axe-core` runs inside those browser scenarios for automated WCAG checks, but
its result is only partial evidence; keyboard, focus, screen-reader, and manual
review remain necessary.

WHATWG URL and URLPattern own parsing and matching behavior. TanStack Router is
the worked reference for propagating typed path/search parameters through links,
loaders, preloading, error/pending boundaries, and code splitting. Gust keeps
explicit compiler-visible route declarations rather than adopting React or
filesystem routing.

HTML forms and constraint validation remain the platform baseline, with WCAG
and WAI-ARIA governing accessibility. Conform is the implementation reference
for deriving field metadata and validation from one schema while preserving a
functional server-submitted form without JavaScript. Gust owns the schema/RPC
relationship, server authority, typed error paths, focus behavior, and generated
markup; it does not inherit Conform's React hooks or Zod dependency.

## Configuration and secrets

.NET's provider pipeline and Options pattern are the primary reference for
ordered configuration sources, last-provider precedence, binding into typed
settings, validation at startup, immutable snapshots, and explicit reload
notifications. Gust should prefer validated snapshots over ambient per-read
lookups so a request or job does not observe half of a reload.

OpenBao is the provider-backed secret-lifecycle reference: opaque secret
handles, TTLs, renewable leases, replacement, expiry, and revocation. Gust does
not embed a secrets manager. It defines a narrow provider protocol and keeps
provider paths, credentials, and raw secret bytes outside ordinary application
types, logs, serialization, and errors.

## Transactional messaging and uploads

The first Gust-maintained transactional-email adapter targets Amazon SES v2 and
uses the AWS SDK for Go v2 service package as its worked reference. This reuses
the already-selected AWS configuration, SigV4, HTTP, and crypto evidence. Its
Gust-facing contract is provider-neutral email, not an SES request builder.
Twilio Messaging and its official Go helper are the deferred SMS reference,
added only when a concrete application needs SMS and its consent, regional,
status-callback, and webhook rules.

Uploads have three distinct paths. RFC 7578 plus Go `mime/multipart` inform the
bounded streaming server parser; the AWS Go v2 presigner informs direct browser
upload to a tenant-scoped S3 object; and tus 1.0 plus `tusd` inform resumable
uploads later. Gust owns size/type/checksum enforcement, temporary storage and
object resources, authorization, cleanup of abandoned uploads, scanning hooks,
and the explicit transition from uploading to complete.

## Observability

OpenTelemetry is the interoperability authority for trace context, spans,
metrics, logs, resources, semantic conventions, and OTLP. Gust should emit or
export OTel-compatible signals rather than create a private telemetry universe.

OTel does not replace Gust execution traces. OTel answers how operational
signals propagate and leave the process; `docs/VISION.md` §108 defines a
versioned correctness/authority artifact containing declared and exercised
capabilities, denied attempts, scoped queries, task decisions, lifetimes, typed
errors, and conformance results. The two share request/trace identity where
safe, while Gust preserves stronger tenant scoping, capability provenance,
redaction, and deterministic-test requirements.

## Deployment artifact, health, and rolling upgrades

Before artifact construction, the compiler emits a canonical Application Model
from the typed program's existing service, API, schema, capability, resource,
job, configuration and supplier authorities. Operators bind that provider-
neutral model to an environment; the binding plus an immutable artifact digest
produces the resolved ReleasePlan consumed by a deployment provider. The
Application Model is not a second IR, the environment binding is not source
code, and the ReleasePlan is not an application capability.

Encore is the primary end-to-end architecture reference for reusing one derived
model across local development, validation, diagrams, tracing, permission
derivation and provisioning. Nitric is the provider-boundary reference and a
catalogue of non-uniform mappings; Gust must reject an unsupported semantic
requirement instead of pretending every target supplies it. Lakebed informs the
agent-facing workflow—narrow app shape, explicit inspection, scoped deployment
credentials and private operational state—not Railway integration, which its
public contract does not specify.

Authority generation starts from the declared typed capability ceiling.
Operation-level use may narrow credentials only under sound closed-world
analysis; dead-code elimination, test coverage and accidental call-graph gaps
never grant or remove authority. An already configured application continues
normal processing during a Gust control-plane outage, while deployment,
reconciliation, scaling, rotation and hosted operations may explicitly pause.

OCI is the portable artifact and registry authority. BuildKit is the worked
reference for converting a declared build graph into repeatable, cache-efficient
OCI output, not a required application runtime. The initial Gust release image
contains the native server, Wasm module, generated bridge, content-addressed
assets, release/capability/contract manifests, and explicitly selected migration
artifacts, with no build toolchain in the runtime layer.

Kubernetes supplies mature operational semantics without becoming mandatory:
startup gates initialization, readiness controls traffic and draining, liveness
detects a wedged process rather than transient dependency failure, and rolling
updates bound surge/unavailability and wait for readiness. Gust owns the same
observable contract on a single host, another orchestrator, or Gust Cloud.

On shutdown an instance becomes unready first, stops accepting new RPC and job
claims, tells SSE/WebSocket clients to reconnect where possible, drains bounded
in-flight work, closes pools and resources, and exits before its termination
deadline. Rollout gates also prove old/new RPC contracts, clients, schemas,
messages, and resumable jobs overlap; container health alone cannot prove a safe
upgrade. `docs/DEPLOYMENT_ARCHITECTURE.md` owns the detailed proposal.

## Owning documents

- `docs/HTTP_RPC_ARCHITECTURE.md` owns HTTP server, HTTP client, JSON/RPC, and
  transport conformance details.
- `docs/POSTGRES_DRIVER_ARCHITECTURE.md` owns the PostgreSQL wire driver and
  records the separate query/migration consumers.
- `docs/WASM_DOM_ARCHITECTURE.md` owns the browser boundary and renderer.
- `docs/CRYPTO_PROVIDER_ARCHITECTURE.md` owns crypto/TLS provider selection.
- `docs/SUPPLIER_ADAPTER_STRATEGY.md` owns S3/Stripe references and vendor
  handoff, plus the first SES email adapter, deferred Twilio SMS adapter, and
  multipart/direct-S3/tus upload paths.
- `docs/DEPLOYMENT_ARCHITECTURE.md` owns OCI packaging, health, draining,
  the Application Model/environment binding/ReleasePlan split, provider
  reconciliation, runtime independence, compatibility gates, and rolling-update
  behavior.
- `docs/VISION.md` owns identity, query semantics, migrations, jobs, durable
  workflows, configuration/secrets, observability, and product sequencing.
- `docs/WEB_SLICE_0.md` owns the deliberately bounded first full-stack proof.

[rfc-8259]: https://www.rfc-editor.org/rfc/rfc8259
[serde-json]: https://github.com/serde-rs/json
[json-test-suite]: https://github.com/nst/JSONTestSuite
[go-http-transport]: https://github.com/golang/go/blob/master/src/net/http/transport.go
[sqlc]: https://github.com/sqlc-dev/sqlc
[atlas]: https://github.com/ariga/atlas
[flyway]: https://github.com/flyway/flyway
[webauthn]: https://www.w3.org/TR/webauthn-3/
[oidc-core]: https://openid.net/specs/openid-connect-core-1_0-18.html
[oban]: https://github.com/oban-bg/oban
[otel-spec]: https://opentelemetry.io/docs/specs/otel/
[tanstack-query]: https://github.com/TanStack/query/tree/main/packages/query-core
[vite]: https://vite.dev/guide/
[esbuild]: https://esbuild.github.io/
[lightning-css]: https://lightningcss.dev/
[vue-scoped-css]: https://vuejs.org/api/sfc-css-features.html#scoped-css
[phoenix-channels]: https://hexdocs.pm/phoenix/channels.html
[autobahn-testsuite]: https://github.com/crossbario/autobahn-testsuite
[oci-image]: https://github.com/opencontainers/image-spec
[oci-distribution]: https://github.com/opencontainers/distribution-spec
[buildkit]: https://github.com/moby/buildkit
[playwright]: https://playwright.dev/
[axe-core]: https://github.com/dequelabs/axe-core
[whatwg-url]: https://url.spec.whatwg.org/
[url-pattern]: https://urlpattern.spec.whatwg.org/
[tanstack-router]: https://tanstack.com/router/latest/docs/framework/react/overview
[wcag]: https://www.w3.org/WAI/standards-guidelines/wcag/
[conform]: https://conform.guide/
[temporal-go]: https://github.com/temporalio/sdk-go
[rfc-7578]: https://www.rfc-editor.org/rfc/rfc7578
[go-multipart]: https://pkg.go.dev/mime/multipart
[tus]: https://tus.io/protocols/resumable-upload
[tusd]: https://github.com/tus/tusd
[dotnet-options]: https://learn.microsoft.com/dotnet/core/extensions/options
[openbao]: https://openbao.org/docs/concepts/lease/
[encore-application-model]: https://encore.dev/docs/understanding-encore
[nitric-providers]: https://nitric.io/docs/providers
[lakebed-docs]: https://docs.lakebed.dev/
