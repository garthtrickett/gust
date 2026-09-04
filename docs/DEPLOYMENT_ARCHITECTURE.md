# Deployment artifact, health, and rolling-upgrade architecture

**Status:** proposed deployment architecture, recorded 2026-08-27 and updated
2026-09-01. This note does not activate deployment work, require Kubernetes or
Docker, authorize a runtime dependency, select a hosted control plane, or claim
production readiness. `docs/VISION.md` Part XVII and the active roadmaps remain
authoritative for sequencing.

## Proposal

Use standards and mature controllers for focused behavior rather than building
a Gust-specific container format or orchestrator:

1. The [OCI Image Format][oci-image] is normative for the immutable packaged
   artifact and multi-platform index.
2. The [OCI Distribution Specification][oci-distribution] is normative for
   registry push, pull, discovery, and content identity.
3. [BuildKit][buildkit] is the primary worked reference for converting an
   explicit build graph into repeatable, cache-efficient OCI output.
4. Kubernetes [startup, readiness, and liveness probes][k8s-probes] are the
   primary health-semantics reference.
5. Kubernetes [Deployments][k8s-deployments] are the primary worked reference
   for bounded surge/unavailability, minimum readiness, progress deadlines,
   revision history, pause, and rollback.
6. Kubernetes [Pod termination][k8s-pod-lifecycle] and lifecycle hooks inform
   signal, unready, drain, and termination-deadline behavior.
7. Gust owns the release manifest, capability/configuration binding,
   compatibility gates, graceful application drain, audit trail, rollback
   policy, and orchestrator-neutral public contract.

OCI and Kubernetes are not the same decision. OCI makes a release portable;
Kubernetes demonstrates good controller behavior. A Gust release must retain
the same health and drain semantics on one Linux host, Docker, another OCI
runtime, another orchestrator, or Gust Cloud.

## Application model, environment binding, and release plan

Do not collapse source authority, operator policy, and provider actions into one
manifest. The deployment input has three distinct layers:

```text
typed Gust program
  -> compiler-owned Application Model
  +  operator-owned Environment Binding
  +  immutable artifact identity
  -> resolved ReleasePlan
  -> deployment-provider reconciliation
```

The **Application Model** is a canonical compiler-emitted projection of existing
typed authority, not a second compiler IR and not a separate source scanner. It
records the logical services, APIs and schemas; jobs and schedules; capability
and resource requirements; operation-level authority ceilings; supplier
dependencies; configuration and secret references; and the relationships among
them. It must be reproducibly derived from the same typed program and canonical
manifests that code generation accepts, so the executable and deployment model
cannot drift.

The **Environment Binding** is operator-owned. It selects the deployment
provider, region, capacity and policy; binds logical resources to managed or
existing resources; selects approved supplier adapters; and resolves secret
references without placing secret values in source or the Application Model.
Local, preview, staging and production environments may satisfy the same model
differently without changing application semantics.

The **ReleasePlan** resolves one Application Model, Environment Binding, and
immutable artifact digest into the exact desired deployment state. It carries
compatibility and migration gates, provider and supplier selections, rollout
and rollback policy, and auditable planned changes. It is the deployment
provider's input; neither the Application Model nor ordinary application code
contains provider object identifiers.

Logical resource instances, application capabilities, and supplier adapters
remain different concepts even though they appear in one graph. A named orders
database has state and lifecycle. A payments capability grants bounded
application behavior. A Stripe adapter implements that behavior. The
deployment provider provisions or binds the substrate. Treating all four as
entries in one undifferentiated `uses` list would erase ownership and authority
boundaries.

### Permission derivation

The capability contract establishes the maximum authority a program may
receive. The compiler may narrow generated provider credentials from proven
operation-level use only when the call and resource graph is statically closed
and the provider can represent the distinction. Dynamic dispatch, migrations,
recovery paths, generated plumbing, or incomplete analysis require a
conservative result or an explicit deployment refusal.

Optimizer reachability, current dead-code elimination, and whichever tests ran
are never authorization inputs. A source or type-level authority change must be
visible as an Application Model and ReleasePlan diff; deployment must never
silently widen authority to make a provider mapping succeed.

## Deployment-provider boundary

The deployment path has one provider-neutral control-plane boundary:

```text
gust deploy
  -> Application Model + Environment Binding + immutable release
  -> capability/configuration validation + resolved ReleasePlan
  -> deployment-provider reconciliation
  -> provider resources
```

A deployment provider is not an application-visible Gust capability. An
application declares requirements such as PostgreSQL, secrets, outbound mail,
and storage. The deployment layer selects infrastructure and supplier adapters
that satisfy those requirements. Treating an entire cloud as one broad
`Deploy` capability would mix application authority, infrastructure mutation,
state management, and operator-only observability into one surface.

The provider interface is conceptually reconciliation-oriented:

- `Plan` reports the changes needed to reach the desired release state;
- `Apply` converges toward that state and is safe to retry;
- `Status` reports observed state against the requested release;
- `Rollback` selects a previously recorded immutable release and applies the
  same compatibility and state-safety gates.

These names describe the architecture, not committed Gust source syntax. The
interface consumes logical resource contracts rather than one flat collection
of vendor operations: compute services, workers and jobs; database lifecycle;
secret references; domains and certificates; and logs, metrics and operational
status. In particular, a PostgreSQL resource retains its own identity, backup,
restore, migration and deletion policy rather than being hidden behind
`CreateService`, and log access is not part of the mutation API.

The adapter owns translation to a pinned provider API, provider identifiers,
idempotency and retry behavior, rate limits, error normalization, and evidence
against the shared deployment conformance corpus. The canonical plan and audit
record retain the selected provider, resolved resource identities, artifact
digest and material changes. Raw secret values never enter the plan or audit
record; the plan carries logical secret references that the target binds at the
deployment boundary.

Provider choice should be invisible to ordinary application logic but explicit
to operators. Application code and immutable release artifacts are portable
across conforming providers; databases, stored data, regions, backups, DNS,
secrets and provider-specific operational state move only through an explicit
migration and recovery plan.

### Initial implementations

The bare-Linux-VM proof is the first independent implementation of the release
and lifecycle contract. Railway is the proposed first hosted adapter because
its current [public API][railway-api], [templates][railway-templates], and
[PostgreSQL service][railway-postgres] fit the first slice. Render, whose
[API][render-api] independently covers services, managed datastores, deploys,
logs and domains, should be the second implementation before the provider
interface is frozen. Northflank's [API/OpenAPI surface][northflank-api] is worth
evaluating early; Fly's lower-level [Machines API][fly-machines] is a later
stress test.

This provider-led sequence is the current proposal recorded against open OD-10;
it does not select a permanent Gust Cloud substrate or resolve the distribution
decision. If Gust owns the customer
relationship, billing, support, incident response, or data obligations while
another provider supplies the infrastructure, that is an explicit operating
model, not a hidden adapter default.

### Distribution and Gust Cloud sequencing

Implementation and channel expansion are intentionally serial:

1. prove the artifact, release, health, and lifecycle contracts through a bare
   Linux VM and self-hosting;
2. make Railway the first blessed hosted route;
3. add Render as the independent second provider and conformance target;
4. support generator partnerships after the Application Model and release
   contract are stable;
5. add cloud marketplaces and appliances when demand pays for their packaging,
   certification, support, and upgrade obligations;
6. consider Gust Cloud only after demand and operating readiness are proven.

The first product needs one blessed hosted path and one independent escape
hatch, not simultaneous adapters for every provider. Gust retains the CLI,
project format, Application Model, Environment Binding, `ReleasePlan`, provider
conformance corpus, and developer relationship regardless of which provider
runs the resources.

A future Gust Cloud requires repeated user demand; provider limits that block
material Gust-specific value; enough deployment volume for a real operations
team; a clear advantage from hosted capability governance, auditing, or
rollouts; acceptable provider economics and customer ownership; and readiness
to own billing, support, security, backups, and incident response. It must use
the same provider-neutral contracts and preserve runtime independence: a Gust
control-plane outage may stop new deployments and reconciliation, but not an
already configured application.

### Focused architecture references

[Encore's Application Model][encore-application-model] is the primary worked
reference for deriving services, APIs, schemas, databases, topics, buckets,
secrets and relationships from application code, then using that shared model
for local development, validation, documentation, tracing, permission
derivation and provisioning. Gust does not adopt Encore's SDK declarations,
parser constraints, runtime or managed control plane. Gust can derive the model
from native typed capabilities and compiler-owned manifests rather than
recovering it from library calls.

[Nitric providers][nitric-providers] are the focused reference for pluggable
resource mappings and, equally importantly, for visible provider mismatch. A
missing or weaker target primitive is evidence for a conformance profile or
deployment refusal, not permission to change application semantics or expose a
provider SDK as a silent escape hatch.

[Lakebed][lakebed-docs] is an agent-workflow reference: a narrow application
shape, inspect-before-guessing commands, deploy-scoped credentials, bounded
database inspection/export, and private-by-default hosted operational data.
Its public documentation does not define Railway as its provider contract, so
it is not the authority for the Railway adapter or the provider abstraction.

Normal request, job and resource processing must not depend on a Gust-managed
deployment control plane remaining reachable. A control-plane outage may stop
new deployments, reconciliation, scaling, credential rotation and hosted
operational views; it must not stop an already configured application. Runtime
independence does not imply operational independence, and every remaining
control-plane dependency belongs in the release contract and outage corpus.

## Immutable release artifact

The first production-shaped artifact is one OCI image or platform index
containing only runtime material:

- the native Gust server binary and required pinned runtime/provider libraries;
- the frontend Wasm module and generated JavaScript bridge;
- deterministic content-addressed CSS, images, fonts, and other assets;
- canonical RPC, capability, supplier, configuration-schema, and release
  manifests;
- explicitly selected migration files and compatibility metadata;
- licenses, provenance references, and later SBOM/attestation artifacts;
- a non-root default user, fixed entry point, and no compiler, source tree,
  package manager, credentials, or build cache.

The OCI descriptor digest is the release's content identity. A mutable tag is a
discovery name, not evidence of what ran. Deployment records and audit events
store the resolved digest, target platform, Gust/compiler/runtime versions,
contract hashes, schema compatibility range, capability/provider selections,
and configuration version.

BuildKit informs concurrent dependency resolution, cache keys, secret-safe
build mounts, multi-platform output, and OCI export. Gust's canonical build
graph remains declarative and reproducible; Dockerfiles, BuildKit LLB, Nix, or a
future native emitter are replaceable frontends behind that graph. BuildKit is
not linked into the application runtime.

## Health contract

Health is three separate questions with different operational consequences:

| Probe | Question | Failure consequence |
| --- | --- | --- |
| Startup | Has initialization completed enough for ordinary health evaluation? | Keep traffic away and allow bounded startup; restart only after the startup deadline. |
| Readiness | Can this instance safely accept new work now? | Remove it from traffic and new job/subscription claims without killing it. |
| Liveness | Is the process irrecoverably wedged rather than merely degraded? | Restart the process after the declared failure threshold. |

Liveness must not depend on PostgreSQL, S3, Stripe, DNS, or another transient
supplier: restarting every instance during a shared dependency outage is an
amplifier, not recovery. Readiness may reflect inability to serve the declared
traffic class, but its dependency policy is bounded and explicit. Startup may
include one-time initialization and compatibility checks but not perform an
unreviewed destructive migration.

Probe handlers are cheap, bounded, unauthenticated only on a private listener or
explicitly protected path, and reveal no tenant data, configuration, secret,
version inventory, stack trace, or supplier diagnostic. Rich diagnostics belong
in privileged operational surfaces and traces, not the public health response.

## Graceful drain

The application owns shutdown semantics; an orchestrator cannot infer them from
SIGTERM. The common state machine is:

```text
STARTING -> READY -> DRAINING -> STOPPED
                \-> NOT_READY -/
```

Entering `DRAINING` must atomically make readiness false and then:

1. stop accepting new connections, RPCs, mutations, job claims, stream joins,
   and subscription claims;
2. allow edge/load-balancer removal to propagate while existing connections
   remain bounded;
3. tell SSE/WebSocket clients to reconnect where the protocol permits, while
   preserving only application-level resumable cursors;
4. finish, cancel, or checkpoint in-flight HTTP/RPC work according to its
   declared deadline and idempotency policy;
5. return uncompleted durable jobs to recoverable state without claiming
   exactly-once execution;
6. flush bounded telemetry/audit buffers and close database, HTTP, TLS, file,
   timer, task, listener, and provider resources exactly once;
7. exit before the deployment termination deadline, after which forced
   termination is recorded as a failed drain.

Kubernetes `preStop` may delay or signal this process, but the termination grace
period already includes the hook. Correctness cannot depend on a hook being
delivered exactly once. The binary must perform the same drain when run directly
and sent the configured termination signal.

## Rolling-upgrade controller behavior

The first rollout model follows the useful Kubernetes Deployment invariants:

- immutable old and new release digests coexist;
- `maxUnavailable` bounds lost capacity and `maxSurge` bounds temporary excess;
- a new instance counts only after startup and readiness succeed for the
  minimum-ready interval;
- a progress deadline fails a rollout that never becomes healthy;
- pause and rollback select an earlier immutable digest rather than rebuilding
  it;
- termination begins only when replacement capacity and compatibility policy
  permit it;
- every transition and override is auditable.

Canary percentages, workspace cohorts, metrics-driven analysis, and automatic
promotion are later controller features. Do not make Argo Rollouts or another
progressive-delivery system a prerequisite for the first rolling replacement.
Gust Cloud may use such a controller behind the same release and health
contract.

## Compatibility gate

Green probes prove an instance can run; they do not prove old and new releases
can coexist. Before traffic shifts, the rollout gate checks:

- RPC and public HTTP contracts accepted by the previous client release;
- frontend assets and contract hashes during clients with old pages still open;
- expand/contract database compatibility and the supported schema range;
- old and new job/message schemas, idempotency behavior, and resumable cursors;
- session/cookie/token/key overlap and provider configuration compatibility;
- supplier adapter and capability-contract compatibility;
- migration/backfill ordering and rollback limitations.

Database changes use expand, deploy compatible readers/writers, backfill, and
contract only after the old release is absent. Rollback is not advertised when
a migration or external side effect made it impossible; that requires an
explicit forward-recovery plan and operator approval.

## First deployment slice

The first proof remains deliberately small:

1. produce one deterministic linux/amd64 OCI image for the typed-ping server and
   static Wasm/assets;
2. validate its OCI layout, manifest, configuration, non-root entry point, and
   exact digest;
3. run it in a disposable OCI runtime with no build toolchain or credentials;
4. prove startup, readiness, and liveness states independently;
5. send the termination signal during idle and in-flight HTTP requests and prove
   readiness drops before bounded drain and exit;
6. run old and new digests together behind a disposable proxy, shift traffic,
   and prove compatible requests plus rollback to the old digest;
7. record release identity, health transitions, drain result, rollout decision,
   and resolved digest in the audit artifact.

This slice does not require multi-region scheduling, autoscaling, preview
environments, canaries, workspace cohorts, a hosted registry, automatic
migrations, or a Gust deployment CLI.

## Conformance corpus

Deployment evidence includes:

- byte/digest reproducibility from the same declared inputs and explicit
  treatment of timestamps and platform differences;
- OCI image/layout validation, registry push/pull by digest, and corrupted or
  incomplete blob rejection;
- missing config, secret, provider, migration, or incompatible-contract
  startup failures with redacted diagnostics;
- startup/readiness/liveness truth tables, thresholds, timeouts, and dependency
  outages;
- termination before accept, during headers/body/response, during RPC handler,
  during jobs, and with active SSE/WebSocket clients;
- stuck drain, forced termination, retry/idempotency, job recovery, cursor
  resumption, and no leaked connection/resource ownership;
- zero-capacity, bounded-surge, failed-readiness, stalled-progress, superseded
  rollout, pause, rollback, and audit cases;
- every supported adjacent old/new client, server, schema, message, job,
  session, capability, and provider version pair.

## Rejected starting points

- **A Gust-specific image format:** it creates registry/runtime work without
  product differentiation; OCI already supplies portable content identity.
- **Kubernetes as an application requirement:** its controller semantics are a
  reference, while Gust's public release and health contract remains portable.
- **Liveness as a deep dependency check:** it turns supplier outages into
  restart storms and destroys useful diagnostics.
- **A single `/health` boolean:** startup, readiness, liveness, and privileged
  diagnostics have different consumers and consequences.
- **State-preserving process upgrades:** immutable side-by-side releases and
  explicit wire/schema overlap are easier to reason about and audit.
- **Canary control plane before ordinary drain:** progressive rollout cannot
  compensate for a process that lies about readiness or loses in-flight work.

[oci-image]: https://github.com/opencontainers/image-spec
[oci-distribution]: https://github.com/opencontainers/distribution-spec
[buildkit]: https://github.com/moby/buildkit
[k8s-probes]: https://kubernetes.io/docs/concepts/workloads/pods/probes/
[k8s-deployments]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
[k8s-pod-lifecycle]: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
[railway-api]: https://docs.railway.com/integrations/api
[railway-templates]: https://docs.railway.com/templates/create
[railway-postgres]: https://docs.railway.com/databases/postgresql
[render-api]: https://render.com/docs/api
[northflank-api]: https://northflank.com/docs/v1/api/use-the-api
[fly-machines]: https://fly.io/docs/machines/api/
[encore-application-model]: https://encore.dev/docs/understanding-encore
[nitric-providers]: https://nitric.io/docs/providers
[lakebed-docs]: https://docs.lakebed.dev/
