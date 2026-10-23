# Production native package enrollment

This capability enrolls the dedicated Ed25519 identity `gust-native-release-1`,
public key `6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550`.
The signing, private custody, withdrawal and replacement owner is `garthtrickett`.
Private material is outside source, agent state and qualification evidence.

The exact public identity, signed manifest, signature and actual issued/expiry
times are checked in beside the worker under `experiments/cranelift/production/`.
Release epoch and minimum package epoch are 1; key epoch range is 1–1.
The maximum offline validity is 604800 seconds, with expiry exclusive.
An expired worker snapshot rejects production admission, including offline use.

Only the worker-pinned manifest is accepted for this production package. It binds
the adapter/header, zlib 1.3.2 source and static archive, build options, runtime,
static startup/system archive closure, tool identities and source provenance.
The worker stages all verified bytes privately. It extracts only the ten exact
static closure members, rechecks the staged runtime and closure before linking,
and invokes the pinned `/usr/bin/ld` with a fixed static argument sequence.
The resulting ELF must have neither interpreter nor dynamic program headers.
Source/environment linker expansion and runtime substitution remain rejected.
The package is GNU/Linux x86_64 ELF for its exact pinned Ubuntu tool profile;
this is not a claim of portable arbitrary C loading or native memory isolation.

Renewal, package replacement, key rotation, signer revocation and manifest-digest
withdrawal require an explicitly reviewed worker/snapshot publication by the
same owner, advancing the release epoch. The new publication must enumerate its
package/key epoch ranges, exact artifacts, freshness interval, revoked key IDs
and withdrawn manifest digests. No environment or package field updates trust.
An older worker remains usable only within its original bounded interval.
No independent snapshot-update protocol is introduced.

The owning build and FFI CI jobs select Ubuntu 24.04 and use
`production/build-toolchain.json`: sixteen exact revisions of existing build
dependencies, public Ubuntu snapshot URLs and archive SHA-256 values, plus the
exact Rust toolchain revision. `scripts/phase26_production_toolchain.py` verifies
local versions or downloads those archives without installing anything. Its
installation mode is confined to the owning ephemeral GitHub job, requires the
dependencies already to exist, and uses normal package resolution without
forcing dependencies or removing packages. Exact artifact equality remains the
qualification gate. Package archives are reproducible inputs, not environment
inputs to production trust. The public snapshot service is documented at
<https://snapshot.ubuntu.com/>.

Reproduce with `just guard-cranelift-phase26-zlib-adapter` followed by
`just guard-cranelift-phase26-production-trust`. The second guard assembles an
unsigned candidate from public inputs and compares its complete manifest to the
worker pin before attaching the existing public signature. An artifact/toolchain
mismatch fails and retains the candidate for review; it never signs or substitutes
that candidate automatically. The clean-tools reproduction uses the real frontend,
worker and installed package path with a cleared environment and isolated network
namespace. The launcher verifies a changed namespace, then drops to the original
uid/gid before executing the frontend, worker or generated programs. Signed production
unit tests separately exercise offline signature/freshness, missing/tampered
artifacts, wrong target, runtime substitution and staged-byte mutation. Native
compress/decompress/empty cases execute, with deterministic repeated linking.
The existing C adapter matrix covers incompressible/empty input, malformed input,
zero/short capacity, invalid/overflow counts, overlap and allocation failures.

Historical test profiles and test keys retain their own registry and fixtures;
they are never production roots. Their empty-production historical records are
projected exactly by the additive enrollment registration. Operational lane-state
prose is excluded from compiler byte pins; compiler source, workflow, canonical
inventory and all other predecessor obligations remain checked. The registration
must reject source substitution, projection tampering and reintroduction of that
operational pin, while forwarding foreign rows to their owning guards.

This package capability does not qualify the Stdlib wrapper or close Phase26.1.
The ticket-publication prerequisite, merged public wrapper/audit, R5 regressions,
native fixed point and R6 exact-final-main Historical closure remain required.
OD23 public resource admission remains deferred; transfer clearing is unchanged.
