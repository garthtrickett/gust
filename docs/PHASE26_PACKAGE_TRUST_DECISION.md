# First-release native-package trust ownership — OD-22 proposal

**Status: OPEN proposal, registered 2026-10-22.**
[VISION §0.15](VISION.md#015-open-decisions) owns the status. This is not part
of the operator's delegated OD-20 A–C decisions and does not block the
independent generic collection repair.

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

## Proposal for the first release

Use an operator-designated release owner and dedicated production Ed25519
identity, with the private key kept outside the repository and agent state.
Only its approved public identity and release data enter the trusted worker
snapshot and package registry through the owning Cranelift publication.
Name the withdrawal/replacement owner explicitly, even if initially the same
person. Keep snapshot updates coupled to pinned worker releases for this
first profile; do not add a separate update protocol by inference.

Before enrollment, the authority record must name:

1. release/signing owner, public key ID and public verification key;
2. withdrawal/replacement owner and the approved key epoch range;
3. snapshot release epoch, minimum package epoch, issued/expiry times and
   offline freshness limit;
4. the actual approved adapter/header/zlib/runtime artifact set and its
   reproducible build identity; and
5. the review and publication path for replacing a package, withdrawing a
   digest, revoking a signer or renewing an expired snapshot.

This is a proposal. No key, identity, validity interval, production package or
external publication is selected here. No CI secret, variable, permission or
workflow configuration change is authorized. The delegation to decide OD-20
does not authorize the registrar to invent a production trust owner.

## Owning work and evidence

The operator designates the trust and withdrawal authorities. Cranelift owns
enrollment and the exact trusted-worker/package implementation and regression
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
