# Selected epoch2 production renewal

The operator delegated epoch2 renewal and then selected a GitHub-generated
identity through “Whichever you rexkon”, after the enrolled private key was
confirmed unavailable through GitHub. The selected identity is
`gust-github-release-1`, public key
`edb0cc88828921e2c3cc7cc6633f646a7b72537331b3ea578e365c8a5fd94dae`.
Release epoch2, minimum package epoch2, key epochs2–2 and the seven-day maximum
remain unchanged. This supersedes the earlier same-key parameter for this new
candidate. No package, symbol, ABI, lifetime, resource or OD23 change is selected.

The non-admitting issuer ran on GitHub as `44084383405`, attempt1, at reviewed
commit `052cc79f573f0f2254a43f5ed4c9a0353e3958a4`. Artifact `14329041411`
has ZIP SHA256 `4b7150808b6fb19708e20b8e469d3e1359b07f8f19156c1f2a7af17c6d38c8e6`.
It generated its private key only in the ephemeral runner, verified its signature,
and uploaded only public outputs. No private key was read into agent state,
source or artifacts, and no repository secret was created. The issued key is
one-shot: it is not a persistent GitHub signing service.

The exact manifest SHA256 is
`a855faf64b3df55301f30ff23f955b2f996e20158894b039b7c3eed3faae6ffd`.
The canonical v2-domain message SHA256 is
`9732f3393c5b0ee73ac61f3e35f483589ec354d36ef759412e1c116a9799ce31`.
Actual assembly issue/expiry are `1794918937` / `1795523737`. Public provenance,
identity and reviewed source-enrollment metadata are retained in `production/`.

The worker embeds this exact public key and snapshot. Packages, public-identity
files, environment variables and source requests cannot update worker trust.
Future runs of the operational issuer can produce candidates but cannot replace
the enrolled key. A future identity or epoch needs its own reviewed publication.
The v2/raw64/offline verification policy is unchanged.

Epoch1 worker, manifest, signature, snapshot and public-identity fixtures remain
immutable in `production/epoch1/`. Its original predecessor archive is retained;
a separately pinned v2 archive adds exact current-main blobs needed for the URL
and public-identity successor. The original first-release authority and report
remain historical. No old signature or qualification is relabeled as current.
The actual enrolled revocation/withdrawal lists are empty; applicable contrary
authorized records must be honored rather than cleared to admit a package.

The candidate uses the sixteen exact production dependencies. The shared host
is unchanged. All twelve artifact digests and the public signature were checked.
The assembler's exact bytes are in the signed link provenance; local and CI
reassembly must reproduce those bytes and the enrolled manifest. Updating zlib's
acquisition URL to its official `/fossils/` location changes no archive digest,
commands or test expectations. The Stdlib workflow change is its owner's commit.

`phase26_production_renewal.py validate` verifies the actual signature and current
wall-clock interval; `inversions` checks history and wrong-key, wrong-message,
tamper, missing-signature, rollback and other refusals. The default Rust positive
must verify the real current signature. The history positive explicitly uses the
old key, and still rejects rollback at the new worker.

Final additive registration requires this actual signature. Every predecessor
registry row and assertion remains, using exact predecessor reconstruction.
Current qualification uses separate `release-epoch2.json` and reachable-audit
successors. Static/inversion, current worker/native/public/offline, fixed-point,
product4GiB quota, exact-head CI/artifact parity, reviews/rules and checked merge
remain mandatory. Public cryptographic verification alone is not qualification.

`predecessor-record-control` exercises only the downstream record-refusal seam;
the default full inversions still include it and every other control. A focused
control pass cannot substitute for the complete source/production qualification.

Qualification is established by current-source receipts and exact-head CI, not by
this source record. Final registration, production/public/R5/fixed-point checks,
artifact parity, reviews/rules and merge are mandatory. PR619 is held until this
separate predecessor merges, then rebased. The full activated Phase26 remainder
and OD23 remain open.
# Cold-build execution environment

The owning workflow measures paging before its actual native compiler build.
It keeps the existing protected 4 GiB/two-CPU command and cgroup paging policy.
The chosen precondition prepares 1200 MiB of effective available paging, checks
at least 1152 MiB at payload entry, and permits at most a 1280 MiB job-owned
file to cover the shortfall and filesystem rounding. These are bounded operating
choices, not a universal compiler requirement or an explanation of the earlier
CI kill. Existing paging is preserved; swap is never counted as build RAM.

Provisioning requires live hosted-worker ancestry and matching public repository,
run attempt, job, runner and exact checkout-tree metadata. Shared hosts may use
existing capacity but cannot provision paging through this helper. Allocation
counts with build outputs against the unchanged 2 GiB growth budget and 2 GiB
disk reserve. The file becomes root-owned mode 0600 before activation.

The controller retains resource and termination metadata separately from the
qualified archive. Only the exact owned inode may be released, after confirmed
payload termination and before the unchanged R5 recipe. Cleanup failures retain
the file, fail the build and prevent R5. Artifact patterns contain metadata and
logs only; paging contents are never uploaded. Epoch-1 evidence, the signed
package, quota assertions and release-test expectations remain unchanged.
