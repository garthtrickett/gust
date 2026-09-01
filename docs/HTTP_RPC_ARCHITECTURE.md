# HTTP server and typed RPC architecture

**Status:** proposed platform architecture, recorded 2026-08-27. This note does
not activate HTTP, RPC, networking, browser, compiler, or Stdlib work; assign an
active roadmap lane; authorize a dependency, runtime symbol, ABI/layout change,
or shared-semantic-zone change; or claim production readiness. `docs/VISION.md`
Part IX, `docs/WEB_SLICE_0.md`, and the active lane roadmaps remain authoritative
for product sequencing.

## Decision

Gust should eventually own its HTTP/1.1 server and its typed RPC contract. It
should learn from several focused upstream implementations rather than port one
framework or retain a permanent HTTP parser dependency.

The reference hierarchy is:

1. [RFC 9110][rfc-9110] and [RFC 9112][rfc-9112] are normative for HTTP
   semantics and HTTP/1.1 message syntax and framing.
2. [h11][h11] is the primary worked reference for a small, strict, bring-your-
   own-I/O HTTP/1.1 event and connection state machine.
3. [llhttp][llhttp] is an independent parser, security, pause/resume, and
   malformed-input reference. It is a differential oracle and corpus source,
   not the intended permanent Gust API.
4. Go's [`net/http` server][go-http-server] is the operational reference for
   connection lifecycle, limits, timeouts, keep-alive, draining, and graceful
   shutdown. Its public framework and internal architecture are not a porting
   target.
5. [Connect][connect-go] is the primary worked reference for an HTTP-native,
   browser-friendly typed RPC protocol.
6. The official [gRPC over HTTP/2 protocol][grpc-http2] is the reference for
   procedure paths, deadlines, cancellation, metadata, status, error details,
   and later streaming semantics.
7. [tRPC][trpc] is an ergonomics reference for end-to-end inferred clients and
   Query/Mutation/Subscription concepts. It is not Gust's wire authority.
8. The [WHATWG EventSource contract][eventsource] is normative for the first
   browser server-to-client subscription transport.
9. [RFC 6455][rfc-6455] and the [WHATWG WebSocket API][whatwg-websocket] are
   normative for WebSockets; [`wsproto`][wsproto] is a small Sans-I/O worked
   reference and [Autobahn Testsuite][autobahn-testsuite] is the protocol gate.
10. [Phoenix Channels][phoenix-channels] is the worked reference for
    multiplexed topics, joins, authorization, references, heartbeats,
    reconnects, and connection draining, not for Gust's runtime architecture.
11. Gust owns its public types, resource and effect rules, compiler-generated
   codecs, service manifest, dispatcher, errors, security context, and wire
   compatibility decisions.

`docs/FULL_STACK_REFERENCE_MAP.md` records the adjacent selections for JSON,
outbound HTTP, typed SQL/migrations, identity/sessions, durable jobs, and
observability so those boundaries do not acquire unrelated framework semantics
independently.

The first implementation should be strict HTTP/1.1 plus unary JSON `gustrpc`.
HTTP/2, HTTP/3, streaming RPC, request batching, reflection, and mandatory
Protocol Buffers are later work.

## Layering

```text
owned Socket or TlsConnection
  -> buffered octet reader/writer
  -> strict Sans-I/O HTTP/1.1 connection state machine
  -> bounded Request and Body resources
  -> router / public HTTP handler / gustrpc HTTP adapter
  -> transport-independent generated gustrpc dispatcher
  -> typed native Gust handler
  -> typed response or structured error
```

Each boundary has one job:

- `std.net` and the TLS provider own bytes, deadlines, cancellation, and
  connection cleanup;
- the HTTP/1.1 core turns arbitrary byte chunks into protocol events and turns
  response events into bytes without reading a socket itself;
- the server runtime owns accept loops, per-connection tasks, resource limits,
  request scope, keep-alive, draining, and shutdown;
- the router maps an already validated HTTP request to a handler;
- the `gustrpc` HTTP adapter maps HTTP metadata and a bounded body to the RPC
  envelope;
- the generated dispatcher performs procedure lookup, decoding, validation,
  context injection, handler invocation, and response encoding without knowing
  about sockets;
- application code sees typed inputs, declared capabilities, and `Result`, not
  parser events, raw headers, or transport handles.

The HTTP parser and the RPC dispatcher must both be testable entirely offline.
Networking is an adapter around them, not a prerequisite for proving their
state transitions.

## HTTP/1.1 core

### Sans-I/O state machine

Follow h11's useful architectural idea: one connection object receives arbitrary
byte fragments and emits events such as request head, body data, end of message,
protocol error, and connection close. Sending performs the inverse conversion.
The same parser must behave identically whether bytes arrive one at a time, in
one buffer, or at every possible split point.

Parsing operates on octets. Do not decode the complete request as Unicode or
search a whole request string for delimiters. Header-name normalization, URI
handling, percent decoding, UTF-8 validation, and application decoding happen
at explicit later boundaries.

The connection state machine owns at least:

- request line and status line parsing;
- header field parsing and normalization;
- message length and body framing;
- fixed-length and chunked bodies;
- request completion and reusable keep-alive state;
- HTTP/1.0 versus HTTP/1.1 persistence rules;
- orderly EOF and truncated-message detection;
- explicit rejection of unsupported upgrade behavior;
- response rules that depend on request method or status.

Pipelined requests, if accepted, are parsed in order and initially dispatched
serially per connection. The first server need not invent concurrent response
reordering.

### Strictness and request-smuggling boundary

There is no product "lenient HTTP" mode. The parser and every reverse proxy in
front of it must agree on where a request ends.

The server must reject, rather than guess through:

- conflicting or malformed `Content-Length` values;
- ambiguous `Content-Length` plus `Transfer-Encoding` combinations;
- invalid transfer-coding order or chunk framing;
- obsolete folded headers and illegal whitespace around field names;
- forbidden control characters and invalid request lines;
- header count, header bytes, target length, body bytes, chunk extension, or
  trailer limits being exceeded;
- premature EOF, framing overflow, and numeric overflow;
- unsupported protocol upgrades.

llhttp's strict mode and malformed-input tests are useful independent evidence.
Its leniency switches are specifically not a product feature.

### Server lifecycle and resources

The server surface should expose safe configuration rather than ambient global
state. It needs explicit, bounded defaults for:

- maximum request-line, header, trailer, and body sizes;
- maximum header count and maximum requests per keep-alive connection;
- header-read, body-read, response-write, idle, and total request deadlines;
- accepted connections and in-flight requests;
- per-client and global overload behavior;
- graceful shutdown deadline and connection draining;
- development diagnostics versus public error detail.

Each accepted socket, request body, response body, listener, and per-connection
task has exactly one owner and deterministic cleanup. Cancellation must wake a
blocked read or write and must not permit a handler to continue using a closed
request arena or connection.

Responses become committed once their head or first body byte is written. After
that boundary an application error cannot be replaced with a new status; it can
only terminate the body/connection and be recorded as a server-side failure.

### Deployment boundary

The first production deployment should place an established edge proxy or load
balancer in front of Gust. The edge may terminate public TLS, HTTP/2, HTTP/3,
compression, and deployment-specific denial-of-service controls, then forward
strict HTTP/1.1 to Gust.

That is a rollout boundary, not permission to build a weak origin server. Gust
still validates all framing and limits independently and must behave safely when
run without the preferred edge in development or self-hosted environments.
End-to-end TLS or direct public serving remains possible through the provider
boundary in `docs/CRYPTO_PROVIDER_ARCHITECTURE.md`; it is not required to make
HTTP/2 part of the first server.

## Outbound HTTP client

The parser/state-machine core should support both roles, but a production client
needs policy and lifecycle beyond parsing responses. Use Go's
[`net/http.Transport`][go-http-transport] as the primary worked reference for
connection reuse and pools, dial/TLS/response/idle deadlines, cancellation,
request-body rewindability and response-body ownership, retry eligibility,
redirect credential rules, proxy/CONNECT behavior, idle eviction, and shutdown.

Gust owns a smaller capability-shaped client. It must:

- bind destinations to declared network or supplier authority;
- keep DNS, sockets, TLS connections, request bodies, and response bodies under
  deterministic resource ownership;
- retry only when both the failure point and declared operation permit replay;
- strip or reject credentials and signatures across redirect authority changes;
- bound headers and bodies in both directions;
- propagate deadlines and cancellation through connection acquisition and I/O;
- expose raw URL/header control only through an explicit networking capability;
- keep connection-pool state out of request arenas and close it at deployment
  shutdown.

S3 and Stripe are the first concrete consumers. Their adapters must sign or
authenticate the exact bytes sent by this client and must not carry a private
transport with different redirect, retry, TLS, or redaction rules.

## JSON serialization

[RFC 8259][rfc-8259] is normative. [Serde JSON][serde-json] is the primary
worked reference for strongly typed reader/writer codecs, and
[JSONTestSuite][json-test-suite] supplies hostile must-accept, must-reject, and
ambiguous cases.

Gust generates bounded monomorphic codecs rather than importing Serde's trait,
derive, generic `Value`, allocator, or package model. The generated contract
must fix integer ranges, UTF-8 and escape handling, duplicate and unknown-field
policy, nesting and total-size limits, allocation/cleanup on partial decode,
path-aware redacted errors, and deterministic schema/manifest hashing. JSON
object emission order is not by itself a canonical contract definition.

## `gustrpc`

### Contract ownership

The Gust service declaration or its temporary ordinary-declaration fallback is
the source of truth. The compiler/tooling derives one monomorphic contract from
it; there is no runtime type reflection and no separately handwritten client
schema.

Generated artifacts are:

- a canonical service and procedure manifest;
- a stable contract hash and format version;
- per-procedure input and output JSON codecs;
- input validation;
- a transport-independent backend dispatcher;
- a native handler interface;
- a frontend Wasm client stub;
- public documentation or a later compatibility descriptor where requested.

The forbidden boundary types in `docs/WEB_SLICE_0.md` remain forbidden. Raw
pointers, references, arenas, database transactions, sockets, files, DOM nodes,
threads, functions, and other linear or opaque handles cannot become RPC data.

### Initial unary wire shape

The initial transport is deliberately ordinary HTTP:

```text
POST /<package>.<Service>/<Method>
Content-Type: application/gust+json
Accept: application/gust+json
X-Gustrpc-Contract: <stable contract hash>
X-Gustrpc-Version: 1
X-Request-Id: <bounded identifier>
X-Idempotency-Key: <required only by declared mutation policy>

<one bounded generated JSON value>
```

Header spellings and media type are proposed wire details, not yet committed
public API. The enduring decisions are the stable procedure identity, explicit
format version, contract hash from the first consumer, bounded body, generated
codec, and separation of transport metadata from application input.

Use `POST` for every Slice 0 call. A later query may opt into `GET` only after
canonical input encoding, URL limits, cache keys, authorization variance, and
side-effect freedom are mechanically proved. A declared mutation is never
silently converted into a cacheable or automatically replayable request.

### Query and mutation behavior

- A **Query** is read-only. A generated client may retry only failures proven
  safe by the retry policy and deadline.
- A **Mutation** changes state. Automatic retry requires an explicit
  idempotency policy and key; the server owns duplicate suppression and the
  retention/tenant rules for that key.
- The HTTP transport itself does not guess whether a call is retryable.
- A deadline and cancellation token belong to the call context, not the
  serialized application input.
- Authentication, resolved tenant, authorization, tracing, audit metadata, and
  request identity are server-injected immutable context. A client cannot set
  them by adding fields to JSON.

Streams and subscriptions inherit the same procedure identity and typed message
contract later, but require an explicit framing, ordering, backpressure,
resumption, cancellation, and browser transport decision. Unary RPC must not
grow an accidental streaming protocol before that work is authorized.

### Errors

The response always separates transport failure from application failure. The
stable error envelope needs:

- a bounded machine-readable Gust error code;
- a safe public message, optional and independently redactable;
- typed or versioned details only when declared by the procedure;
- request identity for support and audit correlation;
- retry classification or retry delay only when the server can support it;
- no stack trace, secret, SQL text, provider error stack, filesystem path, or
  internal capability detail.

HTTP status remains meaningful for ordinary clients and infrastructure. The RPC
error code carries the stable application classification. gRPC's status and
error-detail design is a reference, not a reason to return HTTP 200 for every
failure.

### Security and limits

The generated adapter enforces, before handler invocation:

- method, path, media type, version, and contract compatibility;
- body and decoded-value bounds;
- generated schema validation and rejection of forbidden boundary values;
- authentication, tenant resolution, authorization, and capability policy;
- same-origin/CSRF policy for browser credentials;
- deadline and cancellation propagation;
- mutation idempotency and replay policy;
- structured tracing and audit fields;
- public error redaction.

Neither a procedure name nor a client-provided tenant field grants authority.
The dispatcher selects a statically registered procedure, and the server derives
security context from approved credentials and deployment policy.

## Streaming RPC and realtime subscriptions

### Separate semantics from transport

The words in `docs/VISION.md` §44 remain distinct:

- a **Stream** is an ordered best-effort sequence whose lifetime is the call;
- a **Subscription** is a long-lived feed with a versioned resumable cursor;
- **SSE** and **WebSocket** are browser transports, not delivery guarantees;
- **Connect/gRPC streaming** is typed RPC framing, not a durable event store.

Every stream keeps the unary procedure identity, schema, auth/tenant context,
deadline, cancellation, tracing, error redaction, and contract-version rules.
It additionally declares ordering, maximum message and queue sizes, heartbeat
policy, consumer cancellation, producer shutdown, and what happens when the
consumer cannot keep up. Unbounded buffering is never the answer.

### SSE first for browser subscriptions

The first server-to-browser realtime slice uses the WHATWG EventSource format
over an ordinary authenticated HTTP response. It is simple to inspect, works
through the existing HTTP path, supports browser reconnection, and does not
introduce a second bidirectional application protocol merely to push updates.

Native browser `EventSource` cannot attach an arbitrary bearer header. The
initial browser profile therefore uses the existing same-origin secure session
cookie and CSRF/origin policy, or a separately declared generated Fetch-stream
adapter when header-based authentication is required. Do not put a reusable
credential in the event URL; URLs leak through logs, history, diagnostics, and
intermediaries.

Each event contains a typed versioned envelope and an application cursor. The
browser `Last-Event-ID` mechanism may carry that cursor during reconnect, but
the server validates it against tenant, authorization, retention, and schema
policy. A heartbeat comment keeps intermediaries from declaring an idle stream;
proxy buffering must be disabled or detected; cancellation closes the owned
subscription and response body exactly once.

A best-effort Stream may tell the client to refetch after a gap. A durable
Subscription resumes from a database changefeed or event log and delivers at
least once, so its consumer is idempotent. Neither claim is inferred from SSE.

### Connect streaming

Connect is the worked reference for typed streaming envelopes, compression
flags, end-of-stream metadata, structured errors, and generated method shapes.
Connect-compatible server streaming can be added after the Gust-owned stream
contract is stable. Full client-streaming and bidirectional RPC also study the
gRPC model because browser Fetch and intermediary support differ from native
HTTP/2 clients.

Application handlers do not change type or meaning when a Connect adapter is
added. If a browser cannot support a chosen stream transport, generation fails
or selects an explicitly declared adapter; it does not silently poll or buffer
the whole stream as a unary response.

### WebSockets only for genuine duplex work

Add WebSockets when the use case requires ongoing client-to-server messages,
low-latency duplex interaction, or several active topics sharing one
connection. RFC 6455 and the WHATWG API govern the wire/browser boundary;
`wsproto` demonstrates a compact I/O-independent state machine; Autobahn is the
required framing, fragmentation, UTF-8, ping/pong, close, limit, and robustness
corpus.

Phoenix Channels supplies the useful application-protocol reference:

```text
one authenticated socket
  -> many typed topics
  -> explicit join / accepted-or-rejected reply
  -> typed events with request and join references
  -> heartbeat, leave, reconnect, rejoin, and drain
```

Gust does not copy Phoenix processes, PubSub, serializers, JSON envelope, or
framework API. Topic names are compiler-generated stable identities; join is
authorized against immutable tenant context; one slow topic cannot allocate an
unbounded queue or starve others; reconnect re-establishes authorization and
resumes only where the Subscription contract provides a cursor.

### Drain and rollout behavior

During deployment drain the instance becomes unready, rejects new stream joins,
stops claiming durable events for new consumers, and gives existing SSE or
WebSocket clients a bounded reconnect signal/window. It then cancels remaining
streams at the termination deadline and closes all listener, connection, topic,
cursor, and queue resources. `docs/DEPLOYMENT_ARCHITECTURE.md` owns the wider
shutdown and rollout contract.

## Interoperability path

Do not require Protocol Buffers or Connect compatibility to prove Slice 0. The
first useful artifact is one Gust type producing one backend dispatcher and one
Wasm client over unary JSON.

Preserve a later, additive path:

1. stabilize Gust's service/type manifest and compatibility rules;
2. generate Protobuf descriptors for the subset with an unambiguous mapping;
3. expose an optional Connect-compatible unary adapter;
4. run the [Connect conformance suite][connect-conformance] and official clients
   as external evidence;
5. add gRPC and gRPC-Web compatibility only for a concrete interoperability
   need;
6. design streaming separately rather than assuming unary JSON framing extends
   to it.

Application handlers must not change when another adapter is added. If Connect
or gRPC compatibility requires different application semantics, the mapping is
invalid or the shared contract must be revised explicitly.

## What not to port

- Do not port Go's complete `net/http`, Hyper/Tokio, Node's HTTP framework, or a
  framework middleware ecosystem.
- Do not make llhttp a semantic authority or expose its callback/enum ABI as the
  Gust API.
- Do not import tRPC's TypeScript inference, React integration, transformer,
  batching, or framework-adapter model.
- Do not make Protobuf, gRPC service reflection, dynamic descriptors, service
  discovery, retries, load balancing, or compression prerequisites for typed
  ping.
- Do not expose raw header mutation, socket access, arbitrary middleware
  capability, or mutable tenant/auth context to ordinary handlers.
- Do not teach only the Cranelift backend or only MIR-to-C about an HTTP or RPC
  behavior.

## Validation and conformance

The HTTP corpus should include:

- every relevant RFC framing and state transition;
- every possible split point for representative requests and responses;
- differential cases against h11 and llhttp where their accepted contract
  matches Gust's strict profile;
- malformed request lines, headers, lengths, chunks, trailers, and EOF;
- request-smuggling disagreement cases;
- slowloris, limit, timeout, cancellation, keep-alive, drain, and shutdown
  behavior;
- fuzzing from arbitrary octets with bounded time and memory;
- proxy-to-origin interoperability in the supported deployment profiles.

The RPC corpus should include:

- canonical manifest and contract-hash stability;
- generated round-trip codecs for every admitted type shape;
- renamed types and procedures, unknown fields, malformed JSON, numeric bounds,
  and version mismatch;
- forbidden boundary-type compile failures;
- dispatcher behavior without HTTP;
- browser-to-native typed ping over HTTP;
- query retry and mutation idempotency evidence;
- auth, tenant, CSRF, deadline, cancellation, tracing, audit, and redaction;
- later Connect/gRPC interoperability only after the compatible adapter exists.

The realtime corpus should include:

- SSE field parsing, chunk boundaries, heartbeat, reconnect, cursor validation,
  proxy buffering, cancellation, and response cleanup in supported browsers;
- ordered stream completion, typed terminal errors, producer cancellation,
  bounded queues, overflow policy, and slow consumers;
- durable disconnect/resume, retention gaps, duplicate delivery, idempotent
  consumers, schema versions, tenant changes, and authorization revocation;
- WebSocket handshake/origin/auth, fragmentation, UTF-8, ping/pong, close,
  limits, topic joins/leaves, references, heartbeat, reconnect/rejoin, drain,
  and the complete admitted Autobahn profile.

## Sequencing

This document refines, rather than replaces, `docs/WEB_SLICE_0.md`:

1. define the recognized service declarations and forbidden types;
2. generate canonical JSON codecs, manifest, and contract hash;
3. prove handlers and the dispatcher without HTTP;
4. implement the strict offline HTTP/1.1 state machine;
5. add owned listener/connection/request lifecycle and bounded server policy;
6. attach the `gustrpc` HTTP adapter;
7. complete typed ping through the generated Wasm client and browser bridge;
8. harden and publish conformance evidence before claiming a general server;
9. add one typed SSE subscription with explicit cursor/resume semantics;
10. add Connect-compatible server streaming where it is useful;
11. add WebSockets and multiplexed channels only for a demonstrated duplex
    requirement, then run the Autobahn and Gust realtime closure corpora.

The resource/network tail in `docs/STDLIB_FOUNDATIONS.md`, the provider boundary
in `docs/CRYPTO_PROVIDER_ARCHITECTURE.md`, and the browser boundary in
`docs/WASM_DOM_ARCHITECTURE.md` are prerequisites or consumers of this shape.
None of those documents widens the currently active Cranelift or Stdlib patch.

[rfc-9110]: https://www.rfc-editor.org/rfc/rfc9110
[rfc-9112]: https://www.rfc-editor.org/rfc/rfc9112
[h11]: https://github.com/python-hyper/h11
[llhttp]: https://github.com/nodejs/llhttp
[go-http-server]: https://go.dev/src/net/http/server.go
[connect-go]: https://github.com/connectrpc/connect-go
[connect-conformance]: https://github.com/connectrpc/conformance
[grpc-http2]: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
[trpc]: https://github.com/trpc/trpc
[go-http-transport]: https://github.com/golang/go/blob/master/src/net/http/transport.go
[rfc-8259]: https://www.rfc-editor.org/rfc/rfc8259
[serde-json]: https://github.com/serde-rs/json
[json-test-suite]: https://github.com/nst/JSONTestSuite
[eventsource]: https://html.spec.whatwg.org/multipage/server-sent-events.html
[rfc-6455]: https://www.rfc-editor.org/rfc/rfc6455
[whatwg-websocket]: https://websockets.spec.whatwg.org/
[wsproto]: https://github.com/python-hyper/wsproto
[autobahn-testsuite]: https://github.com/crossbario/autobahn-testsuite
[phoenix-channels]: https://hexdocs.pm/phoenix/channels.html
