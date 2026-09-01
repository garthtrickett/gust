# PostgreSQL driver architecture for Gust

**Status:** proposed architecture, recorded 2026-08-27. This note does not
activate implementation work, assign either active lane, authorize a new
dependency, or settle the supplier/effect decisions in `docs/VISION.md`.

## Decision

Use **pgx as the primary implementation reference for a Gust-native PostgreSQL
driver, but do not port pgx wholesale**.

The reference hierarchy is:

1. PostgreSQL's [frontend/backend protocol documentation][pg-protocol] is the
   normative authority for message flow and wire formats.
2. pgx's [`pgproto3`][pgproto3] and [`pgconn`][pgconn] are the primary worked
   references for framing, connection behavior, error recovery, and
   authentication integration.
3. [`rust-postgres`][rust-postgres] is the independent cross-check, especially
   for ownership, malformed-input handling, and the SCRAM state machine.
4. The Gust compiler and runtime own the public API, resource behavior, memory
   lifetimes, capability boundary, and generated type codecs. No Go or Rust API
   shape is authority over those decisions.

This combination fits Gust better than selecting one source repository and
transliterating it. pgx's low layers are concrete and protocol-focused; its
higher layers deliberately contain Go interfaces, reflection-like scan plans,
dynamic registration, caches, pooling, and `database/sql` compatibility that
Gust neither needs nor wants to reproduce.

`docs/SUPPLIER_ADAPTER_STRATEGY.md` generalizes this reference hierarchy to the
initial AWS S3 and Stripe adapters and records how a Gust-maintained reference
implementation can later transfer to a vendor without changing the Gust-facing
capability contract.

## Correct source-package mapping

| Gust layer | Primary reference | Translation objective |
| --- | --- | --- |
| Protocol framing | `jackc/pgx/v5/pgproto3` | Bounded byte cursors; frontend/backend tags; checked lengths; payload encoders and decoders |
| Type marshalling | Small selected parts of `jackc/pgx/v5/pgtype`, plus PostgreSQL docs | Concrete generated Gust codecs keyed by known OIDs; use pgtype for edge cases and test vectors, not as the architecture |
| Connection and wire state | `jackc/pgx/v5/pgconn`, not `pgx.Conn` | Startup, TLS handoff, authentication, command cycles, error resynchronization, transaction status, termination |
| SCRAM authentication | `pgconn/auth_scram.go`, cross-checked against `rust-postgres/postgres-protocol` | SCRAM message state machine over audited runtime crypto primitives |

There is no `jackc/pgx/v5/crypto` package. In current pgx, SCRAM integration
lives in `pgconn/auth_scram.go`; SASL wire messages live in `pgproto3`.

## Gust-native boundaries

### Framing

Port the shape of `pgproto3`: one explicit representation per wire message and
one checked encoder/decoder per representation. The PostgreSQL documentation,
not pgx implementation detail, decides tag values and field order.

Every decoder must validate before allocating or indexing:

- the signed 32-bit length field and its minimum legal value;
- configurable maximum frame and field sizes;
- addition/subtraction overflow while slicing;
- NUL termination and UTF-8 requirements where the protocol requires them;
- field counts, parameter counts, OID counts, and remaining bytes;
- `-1` as SQL `NULL` only in fields where the protocol assigns that meaning;
- trailing or truncated bytes.

The parser is useful before networking exists: captured and generated protocol
frames can exercise it entirely offline.

### Connection resource and state

The low-level model follows `pgconn`, while the exposed type follows Gust's
resource rules. A database connection is a move-only linear resource whose
close operation is enforced exactly once. It is not recovered by a finalizer
and is not copied into replayable application state.

Represent the protocol as an explicit state machine, at least:

```text
Connecting
  -> TLS negotiation
  -> Startup
  -> Authenticating
  -> Ready(I | T | E)
  -> Extended query / Resynchronizing
  -> Ready(I | T | E)
  -> Closed
```

`ReadyForQuery` is the authority for transaction state: `I` is idle, `T` is in
a transaction block, and `E` is in a failed transaction block. After an error
during the extended-query protocol, the connection must send or reach `Sync`,
consume until `ReadyForQuery`, and only then become reusable. A returned
`ErrorResponse` alone does not mean the connection is ready.

The receiver must also tolerate messages valid at multiple points, including
`NoticeResponse`, `ParameterStatus`, and `ErrorResponse`; it must not encode one
happy-path response sequence as the whole protocol.

### Generated type codecs, not a pgtype port

Do not reproduce pgtype's general dynamic conversion planner. PostgreSQL is the
schema source of truth and §55 assigns query/type derivation to the compiler, so
the normal path is:

```text
introspected PostgreSQL type
  -> generated concrete Gust type
  -> generated parameter encoder and result decoder
  -> checked OID/format agreement at the wire boundary
```

The first codec cohort should be intentionally small: booleans, signed integer
widths, text, bytea, UUID, timestamps needed by the demo, and nullable values.
Begin with text parameters and text results unless a type has a compelling,
fully tested binary representation. Add binary, arrays, enums, domains,
composites, ranges, and extension types individually under explicit contracts.

Result memory initially copies into the request/caller arena. Do not expose a
view into a connection read buffer that becomes invalid on the next receive.
Zero-copy rows are a later optimization requiring an explicit lifetime
contract, not an implementation shortcut.

### Authentication and cryptography

Port the SCRAM-SHA-256 *state machine*, not the cryptographic primitives.
Randomness, SHA-256, HMAC, PBKDF2, Base64, TLS certificate processing, and
constant-time verification must come from an audited runtime boundary.
`docs/CRYPTO_PROVIDER_ARCHITECTURE.md` specifies the proposed shared boundary:
a small Gust-owned contract over a pinned OpenSSL 3 provider initially, with
production TLS and primitives remaining inside the audited native provider.

The implementation must:

- require certificate and hostname validation on the product path;
- reject authentication methods it does not support;
- validate the server nonce and server proof;
- bound the server-supplied SCRAM iteration count before PBKDF2 work;
- keep credentials and cancellation keys out of diagnostics and traces;
- support SCRAM-SHA-256 first;
- claim SCRAM-SHA-256-PLUS or `channel_binding=require` only after the TLS
  boundary exposes and tests the required channel-binding data.

## First supported protocol slice

The first native driver should be deliberately boring:

- PostgreSQL protocol 3.0 startup;
- required TLS and SCRAM-SHA-256;
- startup parameters, backend key data, notices, errors, and termination;
- extended-query `Parse -> Bind -> Describe -> Execute -> Sync`;
- values supplied as Bind parameters, never interpolated into SQL client-side;
- one in-flight command cycle per connection;
- text-format results and the initial generated codec cohort;
- explicit transaction state and recovery to `ReadyForQuery`.

Initially exclude:

- the simple-query API as an application parameterization path;
- pooling and statement caches;
- pipelining and multiple in-flight command cycles;
- `COPY`, `LISTEN`/`NOTIFY`, replication, and cancellation;
- arbitrary runtime codec registration;
- every PostgreSQL extension type;
- implicit retries.

These are staged exclusions, not protocol misunderstandings. In particular,
the extended protocol carries parameter values separately and gives a precise
`Sync`/`ReadyForQuery` recovery boundary, which aligns with compiler-generated
queries and removes any need for a client-side SQL interpolation feature.

## Sequencing

The implementation order is constrained by current Gust capabilities:

1. **Prerequisite authority:** an owned socket resource, networking surface,
   TLS and crypto boundary, timeouts/deadlines, cleanup behavior, and database
   effects must have owners and checked contracts.
2. **Offline protocol core:** bounded message encoding/decoding and malformed
   frame tests, with no socket dependency.
3. **Startup and authentication:** connect to disposable PostgreSQL, negotiate
   TLS, complete SCRAM, consume through the first `ReadyForQuery`, and close.
4. **One extended query:** generated SQL plus separately bound parameters,
   row description, data rows, command completion, and resynchronization.
5. **Generated schema codecs:** integrate §55's introspection and concrete
   generated types rather than growing a dynamic conversion framework.
6. **Transactions and failures:** prove `I`, `T`, and `E`, failed-transaction
   recovery, abrupt disconnects, cancellation safety, and exactly-once cleanup.
7. **Ergonomics and throughput:** only then consider pooling, caches, binary
   codecs, pipelining, COPY, and asynchronous features.

No active Cranelift or Stdlib patch is widened by this sequence. The offline
protocol core could be planned independently, but network, resource, runtime,
effect, and compiler-derived surfaces must follow their owning roadmaps and the
shared semantic zone.

## libpq bootstrap option

A narrow libpq wrapper is the fastest way to establish an end-to-end database
oracle while the native networking/TLS/crypto prerequisites are absent. If
used, record it as a temporary bootstrap/reference route rather than silently
making it the product architecture. The wrapper still needs a linear Gust
resource, declared database authority, bounded data copying, deterministic
error translation, and exact cleanup.

The native driver and the libpq route can then run the same conformance corpus:
captured protocol frames, startup/authentication failures, parameterized-query
cases, transaction-state transitions, malformed server messages, and typed
result fixtures. Differential agreement is evidence; libpq does not define
Gust semantics.

## Query compiler and migrations are separate consumers

The wire driver does not define Gust's query language or migration workflow.
Use [sqlc][sqlc] as the primary worked reference for parsing SQL against a
schema/catalog and generating typed parameter/result functions. Gust's compiler
derivation remains broader: the same query walk must emit the result type,
effect requirement, and tenant-scope obligation defined by `docs/VISION.md`
§55.1.

Migration tooling uses a deliberate two-reference split. [Flyway][flyway] is
the operational reference for applying explicit ordered files and recording
history, checksums, and outcomes. [Atlas][atlas] is the design-time reference
for schema inspection, proposed SQL diffs, migration linting, and drift
detection. Atlas-generated SQL is review input and does not auto-apply in
production. Both remain subordinate to Gust's reviewed up/down files, central
manifest, destructive approval, expand-and-contract rollout, resumable
backfills, tenant batching, and supported schema-version ranges.

`docs/FULL_STACK_REFERENCE_MAP.md` records this split alongside the other
full-stack reference selections.

[pg-protocol]: https://www.postgresql.org/docs/current/protocol.html
[pgproto3]: https://github.com/jackc/pgx/tree/master/pgproto3
[pgconn]: https://github.com/jackc/pgx/tree/master/pgconn
[rust-postgres]: https://github.com/rust-postgres/rust-postgres
[sqlc]: https://github.com/sqlc-dev/sqlc
[atlas]: https://github.com/ariga/atlas
[flyway]: https://github.com/flyway/flyway
