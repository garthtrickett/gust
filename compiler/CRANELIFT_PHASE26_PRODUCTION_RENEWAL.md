# Selected epoch2 production renewal

The operator selected this renewal on 2026-11-17 under the existing OD22
policy: release epoch2, minimum package epoch2, key epochs2–2, the same
`gust-native-release-1` Ed25519 public key, and the unchanged seven-day maximum.
No new package, symbol, ABI, lifetime, resource, or OD23 semantics are selected.

The worker still embeds its trust snapshot. Packages, environment variables and
source requests cannot update trust. The epoch1 enrolled worker, manifest,
signature and snapshot are immutable fixtures in `production/epoch1/`.
`compiler/phase26-release/release.json` and the original first-release report
remain historical. Current qualification uses `release-epoch2.json` and a
separate reachable-audit successor, with the same native/public/offline,
fixed-point, quota, exact-head CI and final-main Historical requirements.

The enrolled predecessor has empty revoked-key and withdrawn-digest lists.
This renewal carries those actual source-enrolled lists; it makes no assurance
about unseen compromise facts. An applicable contrary authorized record must
be honored before signing or enrollment, not cleared to admit the package.

The unsigned artifact set was genuinely reassembled in an isolated environment
with the sixteen existing exact production dependencies. Shared-host packages
were unchanged. Its assembler digest is part of the public link provenance;
changing that assembler requires a new actual assembly and message. Snapshot
issue and expiry are the real assembly timestamps, not test-clock substitutes.

`phase26_production_renewal.py prepare-check` and `inversions` check preparation
and refusals only. A real 64-byte public Ed25519 signature over the exact
`gust-approved-native-package-v2\0` domain plus manifest is required by
`validate`, the existing positive Rust test, enrollment and full qualification.
There is no empty, old, generated, or placeholder epoch2 signature.

`handoff NEW_DIRECTORY` writes only the canonical message, public DER key and
public signing request. It never signs or looks for private material. The
operator-controlled signer returns the raw public signature. Then
`accept-public-signature SIGNATURE_FILE` verifies it with the already enrolled
public key and copies it to the absent current signature path. It cannot
replace an existing signature or choose a key, epoch or clock. Signature
verification alone is not qualification.

After that actual handoff, `phase26_production_renewal_registration.py generate`
updates only the active epoch2 authority, its audit and the additive successor
row. It cannot enroll unsigned preparation. Every old registry row and epoch1
assertion remains, using exact predecessor reconstruction. The new guard checks
physical current bytes, omissions, substitutions, duplicates, rollback and
foreign-mutation forwarding. The default Rust population grows by one history
and unsigned/rollback refusal test; none of the old tests is removed or ignored.

Status: unsigned preparation. Actual signature, final enrollment, full current
qualification, authoritative CI/artifact parity, reviews/rules and merge remain
mandatory. The held PR619 correction is rebased only after this separate
predecessor merges. All remaining activated Phase26 work stays open.
