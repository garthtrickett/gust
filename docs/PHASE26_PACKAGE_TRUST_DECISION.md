# First-release native-package trust ownership — OD-22 decision

**Status: RESOLVED 2026-10-22 — trust policy selected under operator delegation.**
[VISION §0.15](VISION.md#015-open-decisions) owns the status. After selecting
OD-21, the operator delegated the signing, trusted identity and withdrawal
choices: “go with what you reckon for these ones”. This is new authority,
separate from OD-20 A–C. Policy resolution is not production enrollment or
release qualification.

## Existing release boundary

[The first-release FFI contract](FIRST_RELEASE_FFI_CONTRACT.md) §3 requires an
explicitly trusted release key or CI signing identity, exact artifact identity,
withdrawal/replacement policy and offline trust/revocation snapshot with a
declared freshness limit. A digest or a signed test fixture does not discharge
those release obligations.

At merged main `6bca6cdde2a3966758fc3fb40e04fc3115e270ad`,
`compiler/experiments/cranelift/src/approved_package.rs` deliberately has:

- `PRODUCTION_SNAPSHOT` with release `unassigned`, zero epoch/times and no keys;
- an empty `PRODUCTION_REGISTRY`;
- a `TrustSnapshot` owned by the trusted worker release, with epoch, validity,
  minimum package epoch, revocations and withdrawn digests;
- an explicit rule that package input cannot update that snapshot, and an
  independently distributed snapshot would require a new authenticated protocol.

The registry's R2/R3 release records also retain empty production signing
roots. These are intentionally unassigned authorities, not a missing test key
to fill automatically. The signed test-profile zlib capability can remain
qualified while the production profile stays closed.

## Decision for the first release

The repository operator, `garthtrickett`, is the initial release/signing owner,
private-key custodian and withdrawal/replacement owner. Signing is performed by
operator-controlled tooling against a reviewed package artifact set. Agents may
prepare reproducible artifacts and public enrollment data; private signing
material stays outside the repository, agent state and evidence archives.

Use one newly provisioned, dedicated production Ed25519 identity with public
key ID `gust-native-release-1`. Trust its exact 32-byte public key after the
operator-controlled setup supplies it and the owning Cranelift publication
pins it. A key ID alone is not enrollment. Test/development keys remain
ineligible. No actual public-key bytes are selected or fabricated in this
record; the selected setup route is a new operator-controlled production key.

Keep trust and revocation snapshots coupled to pinned worker releases. For the
initial profile, use release epoch 1, minimum package epoch 1, and key epoch
range 1–1. Stamp actual issued/expiry times when assembling the release; the
maximum offline validity/freshness window is seven days (604800 seconds).
Expired snapshots fail closed. Renewal, rotation, signer revocation and digest
withdrawal require an explicitly reviewed worker/snapshot publication by the
same release owner, with monotonically advancing epochs. Package or environment
input cannot update trust. This first profile adds no separate snapshot update
protocol; offline users receive withdrawals through a newer worker snapshot,
and an older snapshot remains usable only within its declared validity.

Using one operator for signing and revocation keeps the first-release ownership
clear. A dedicated key separates production trust from test identities and
personal signing keys. A bounded snapshot lifetime limits stale offline trust.
Revisit this choice if renewal or incident response needs a separately delegated
maintainer or an authenticated independent update channel; record that change
before broadening authority.

Before enrollment, the release evidence must contain:

1. the named release/signing owner, selected key ID and actual public verification key;
2. the named withdrawal/replacement owner and selected key epoch range;
3. the selected snapshot/package epochs, actual issued/expiry times and
   seven-day offline freshness limit;
4. the actual approved adapter/header/zlib/runtime artifact set and its
   reproducible build identity; and
5. the review and publication path for replacing a package, withdrawing a
   digest, revoking a signer or renewing an expired snapshot.

The production key must still be provisioned, its public bytes enrolled, and the
actual package/artifact set qualified. Production snapshot/registry contents
remain empty until that owning implementation passes. This record does not
authorize access to existing secrets, a CI secret/variable/permission change,
or a repository configuration change. Signing and enrollment are operational
work under the selected ownership, not an additional unresolved OD-22 choice.

## Owning work and evidence

The operator delegated the choice and the selected authorities are recorded
above. Cranelift owns enrollment and the exact trusted-worker/package implementation and regression
evidence after that decision. Docs/vision records the decision and its limits.
Keep package-controlled or environment-controlled trust substitution rejected.

Qualify the actual production profile with valid and missing, tampered,
unknown-signer, revoked, withdrawn, expired, wrong-target and substituted
artifact inputs; deterministic linking and transitive pins; offline snapshot
verification; and clean-machine zlib execution. Test identities never become
production identities merely because their tests pass. FFI-R5/R6 still require
the complete merged wrapper, full owning regressions and final-main closure
evidence.

## Evidence and limits

The registrar read the current `TrustedKey`, `TrustSnapshot`,
`PRODUCTION_SNAPSHOT` and `PRODUCTION_REGISTRY` definitions and the contract
against the baseline above on 2026-10-22. The source SHA-256 is
`c19dca4da036c62d207001dd7aa73f2cc673a3b4319d896f369928cc91375b82`;
the contract SHA-256 is
`889deabf4a294c63ba37e97eb48823427d36cb916f212ce75227c5dd49470b58`.
This is a static authority audit, not a new signing, linking or native execution
result. All production release claims remain unqualified until their actual
gates pass.
