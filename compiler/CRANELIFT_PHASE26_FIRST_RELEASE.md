# Phase26.1 first-release evidence

This is the compiler-owned closure implementation for the first-release
contract, not a claim that final-main qualification has already passed.
The checked final receipt is produced only after the wrapper and closure
patches merge and Historical Full succeeds on that same final `main`.

The supported integration is zlib 1.3.2 through the enrolled compiler adapter
on `x86_64-unknown-linux-gnu`, with fixed-width signed Int counts, byte spans,
static ELF linking and the separately owned safe native-byte module. Input
and output use independently live checked Arenas. Success is a tagged Index
to the completed output Vector in the explicit output Arena; errors publish
no output ticket. Native temporary cleanup precedes publication.

The public hard output capacity is zero through 1 GiB. Decompression never
allocates from an advertised stream size. Error classes remain -1 arguments,
-2 range, -3 insufficient destination, -4 corrupt input, -5 allocation and
-6 other native failure. Failed call-region allocation is normalized from
its separate runtime status domain to public -5. Gust Arena exhaustion and
checked collection traps retain process-level failure; no unwind or request
containment guarantee is added.

The production identity is `gust-native-release-1`, exact Ed25519 public key
`6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550`.
The initial release/minimum package epochs are 1/1 and the key epoch range is
1–1. The worker-pinned snapshot records actual issued/expiry times with at
most 604800 seconds of validity. The enrolled window is 2026-10-23T02:39:32Z
through 2026-10-30T02:39:32Z; expiry is exclusive and fails closed.
Reviewed epoch-advancing renewal, rotation, revocation and withdrawal remain
worker release changes. Packages, environment variables and independent
update channels cannot substitute trust. The operator retains private-key
custody; qualification uses only the existing public signature.
Reproduction after expiry requires a reviewed epoch-advancing worker snapshot
and operator-signed package renewal. Historical artifacts do not override the
worker clock or grant renewed production admission.

`phase26-release/release.json` binds the exact merged prerequisite commits,
audited source hashes, snapshot, public manifest/signature/identity and artifact
set. `phase26-release/reachable-audit.json` records the targeted input, alias,
copy, native call, validation, error, cleanup, publication and return paths.
It preserves the general nine-origin/seven-route model as OPEN. Unknown
origins and unsupported control flow gain no safe authority. The audit is
specific to the admitted interface and does not close the Phase26.5 collection
audit, OD23 resource admission or general alias immutability.

The two source-hash inventories are data, not fixture execution. Fixture
reachability excludes those exact inventories while preserving real runner
references and the existing staged-fixture allowlist. Refusal controls retain
both the new-unreachable and stale-allowlist checks. The additive predecessor
archive successor preserves the original archive and its projections unchanged.

## Actual owning qualification

The `Cranelift Phase26 First Release` workflow reproduces the approved native
package with the enrolled public toolchain and invokes:

```sh
just guard-cranelift-phase26-release-closure
```

The new workflow launches both `make gust` and the whole owning recipe in a
real cgroup capped at 4 GiB and two CPUs, within the 6 GiB owning maximum.
The launcher verifies the effective ancestral memory limit inside the scope;
the regression runner refuses unbounded execution and records its unchanged
actual limit. Local reproduction uses the same bounded `work`/systemd scope.
No repository permissions, secrets, CI variables or test deadlines change.

The recipe requires additive registration and refusal inversions, the full
Rust compiler suite (78 ordinary passes and 15 existing ignored integration
or diagnostic tests), the three call-region runtime tests, the unchanged native
emitted-object fixed point, actual signed-production admission/negative/offline
qualification and all 16 public native cases plus three frontend rejections.
The evidence checker binds each emitted import source and static executable,
the actual package artifacts, unchanged compiler/runtime/stdlib inputs, command
logs and nonempty byte-identical emitted-object populations. Equal linked
stage executables are retained as the separate D4 observation.

The existing PR Fast, adjacent native/resource/layout, collection-validity,
predecessor projection and release guards remain required. A focused recipe
does not replace their exact-head workflows. Twelve ignored integration tests
retain their separate owning guards. Three existing manual diagnostics are not
counted as release runtime evidence; the authority record inventories each
disposition without changing any ignore attribute. The original malformed/resource
witness is not rerun or upgraded. Runtime partial-allocation tests and the
adapter's separate C allocation-failure diagnostic remain distinct from
production public execution; the public matrix does not claim to force
allocator exhaustion.

The complete safe composition example is
`tests/stdlib_s26_1_roundtrip.gst`. The maintained Stdlib workflow contains
the public package reproduction and full public guard. Reproduction needs
the exact enrolled toolchain/artifact profile, not an arbitrary system zlib.
Neither compiler qualification nor the safe wrapper authorizes distribution,
deployment or access to an installed production secret.

## Final-main gate

After all required source and documentation merge, dispatch the existing
`Cranelift Historical Full` workflow on the exact final `main`. Preserve its
180-minute job limits and registry-derived target/shard population. Once it
finishes, verify the retained closure qualification and review records:

```sh
python3 scripts/phase26_release_closure.py historical \
    RUN_ID QUALIFICATION_ARTIFACT_ID QUALIFICATION_ARCHIVE CLOSURE_PR \
    INDEPENDENT_REVIEWS_JSON NEW_FINAL_RECEIPT_DIRECTORY
```

The checker verifies the owning artifact against its API digest and run, then
checks every retained qualification byte directly inside the archive.
This checks current main before and after verification, exact qualified-tree
identity, unchanged qualification inputs, the closure PR's merged head,
all eligible exact-head PR workflows derived from its actual changed paths,
Trusted Actor, resolved review conversations, independent Standards/Spec reviews,
and every successful Historical job on the same final head. An earlier,
partial, skipped, failed or wrong-head run cannot pass. Unsupported trigger
syntax fails conservatively rather than shrinking the expected workflow set.

Retain the final receipt durably without a result-only commit moving the head
it qualifies. Until that command succeeds and its actual owning evidence is
checked, Phase26.1 remains OPEN. Completion covers the first-release profile
only. `26.1-GENERAL`, `26.1-ABI-EXT`, `26.1-LIFECYCLE-EXT`, `26.1-SQLITE` and
`26.1-DEPLOY`, the later Phase26.2–26.6 gates and the separate native-launch
obligations retain their own OPEN status and authority.
