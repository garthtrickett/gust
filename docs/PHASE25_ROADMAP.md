# Phase 25 — Bootstrap and Residual C Retirement · **ACTIVATED 2026-09-20**

**Lane:** Cranelift. Branches follow `codex/phase25-<patch>-<slug>`.

## Status of this document

This is the patch breakdown Phase 25 did not have. `docs/PHASE25_BOOTSTRAP_SEED_POLICY.md`
decides *what* and *in what order*; it is a decision record, not a task list.
This file is the task list.

**Phase 25 was activated by the operator on 2026-09-20**, which is what
`TASK.md`'s "later phases still need their own activation" requires and what
Phase 24's activation explicitly withheld.

**`TASK.md` has not yet been updated and still names Phase 24 as the active
Cranelift roadmap.** That contradiction is real and is Patch 25.12's work:
127 scripts read `TASK.md` and several assert an immutable Phase N record,
so moving the active-roadmap pointer needs its own patch and a full sweep.
Until then this file is the Phase 25 task list and `TASK.md` is the Phase 24
record; a reader who needs the active roadmap should read both.

**Its lane ownership is unresolved, and that is flagged rather than
assumed.** `AGENTS.md:10-14` gives Docs/vision the `docs/` set while stating it
"owns no code and holds no semantic authority"; the Cranelift capability
registry is Cranelift's. This patch touches both, so on the letter of the
table it has no single owning lane.

The coupling is **forced by the enrolment mechanism, not chosen**. Any
`docs/` file whose text matches the surface patterns joins the manifest, and
`phase23_closure` then fails until it is registered in the Cranelift registry
— across four coordinated files, one of which (`scripts/cranelift_registry.py`)
is itself an enrolled surface. A docs-only patch adding a document that
mentions MIR-to-C is therefore **not constructible**. PR #444 hit exactly this
and merged with the same shape.

Routing it by `AGENTS.md:20-23`'s test — the file it changes and the
*authority* it needs — the registry edit is enrolment bookkeeping rather than
new semantic authority, and this document is an unactivated draft that holds
none. That is an argument, not a ruling. **The operator should settle whether
registration edits are lane-crossing, because the answer applies to every
future document, not to this one.**

**It deliberately lives outside `TASK.md`.** 127 scripts read that file and
several assert an "immutable Phase N record" is preserved. Moving this
breakdown into it is a structural edit that needs its own patch and a full
sweep, not a drive-by append. The activation patch does that move.

## Entry conditions

| condition | state |
| --- | --- |
| `docs/PHASE25_BOOTSTRAP_SEED_POLICY.md` merged | **merged 2026-09-19**, PR #444 as `73862153`, 260/260 checks, zero unresolved threads |
| #433 — seed cannot reconverge | **closed 2026-09-19**, verified on `main`: `make bootstrap` reaches the fixed point and `gust_v4.c` returns unchanged |
| Cranelift object determinism | **unmeasured** — D4's prerequisite; if it fails, 25.2 grows a repair |
| D9's poison test past `std` | **unmeasured** |
| fiber benchmark on musl | **unmeasured** |

The three unmeasured rows are Patch 25.0's work. None gates activation; all
gate the patches that assume them.

## Two strands no decision row covers

Found by measuring the whole tree rather than the three named strands. Both
need a home before the phase claims C removal.

- **`tree-sitter-gust/` — 12,263 lines of generated `parser.c` plus ~900 of
  headers, about 16% of the repository's C.** Invoked by `Makefile:265`
  (`test_tree_sitter`, running `tree-sitter test` and `tree-sitter parse`) and
  `justfile:22605`. The tree-sitter CLI compiles that parser with a C
  compiler. The exit gate says a clean machine builds **and tests** Gust
  without invoking one. Either this is out of scope and the gate says so, or
  it is in scope and needs a patch. **Patch 25.0 decides which; it is not
  decided here.**
- **`src/runtime/core_headers.h` — 379 lines.** Shared struct layouts and the
  C preprocessor macros implementing generics. When six runtime files become
  Gust and two become Rust, who still reads it, and how do the Gust and Rust
  sides agree on layout? Owned by Patch 25.5.

For scale: `gust_v4.c` is 66,002 lines of the tree's 81,563 lines of C and H —
**81%, deleted rather than replaced**. The runtime is 3%.

## Status

Ticked when MERGED TO MAIN, not when written. Two rows below carry an
`a` suffix because a merged patch had to be corrected rather than
amended: 25.11a renumbers the merged 25.11, whose Exit Gate claimed a
green no-C job and an empty expected-failure list when the list had four
entries, and 25.12a is the closure readiness reporter 25.12 needs in
order to have something to assert.

The order here is the document's, not the merge order. Measured during
25.5: `fiber.c` must go before the Gust runtime port, because codegen
injects a `gust_yield()` call into every loop and `fiber.c` is the top
layer, so a Gust `arena.c` with one loop closes arena -> fiber ->
scratch -> arena. The implementation order is 25.6, 25.5, 25.7, 25.9,
25.10.

- [x] Patch 25.0 — C Toolchain Requirement Enumeration
- [x] Patch 25.1 — No-C-Compiler Falsifier and gnu Smoke Job
- [x] Patch 25.2 — Object Determinism and the Fixed-Point Artifact Set
- [x] Patch 25.3 — The Freestanding Gust Subset
- [x] Patch 25.4 — Runtime Crate and Fixture Rehoming
- [x] Patch 25.5 — Runtime to Gust
- [x] Patch 25.6 — `fiber.c` to `global_asm!`
- [x] Patch 25.7 — Native Stage Chain and the New Fixed Point
- [x] Patch 25.8 — Release Mechanics
- [x] Patch 25.9 — Seed Cut-Over
- [ ] Patch 25.10 — Emitter and Bootstrap Entry Deletion
- [x] Patch 25.11 — `cc` Optional
- [x] Patch 25.11a — Renumber the merged 25.11, whose Exit Gate was not met
- [x] Patch 25.12a — Closure Readiness Reporter
- [x] Patch 25.12 — Phase 25 Closure

## Patch 25.0 — C Toolchain Requirement Enumeration

**Purpose:** establish, by measurement, what actually requires a C toolchain.
Phase 24 closed on "28 registered live-C cases": accurate about the registers
and incomplete about the tree. #398 found four further Stdlib guards reaching
the backend through `GUST_RUNNER_ROUTE`, and #422/#424/#420 each record a
census that missed something. An enumeration starting from the existing
registers inherits the same blind spot.

**Steps:**

- Enumerate C-toolchain requirements from the tree, not from any register.
  The registers are a cross-check, not the source.
- Run the three owed measurements and record each: Cranelift object
  determinism; D9's poison test extended past `std` to the runtime archive,
  pthread and the host object; the fiber benchmark on musl.
- **Decide `tree-sitter-gust`'s disposition.** In scope, or excepted with the
  gate reworded to say so. Do not leave it unstated: at 16% of the tree's C
  and reachable from `Makefile:265`, silence reads as an oversight at closure.
- Land the outcome as a tracked inventory with a successor chain, and give it
  an execution route in the same patch — #437's lesson, and #445's.

**Exit Gate:** a tracked, executed inventory of every C-toolchain requirement,
derived from the tree; the three measurements recorded with their commands;
`tree-sitter-gust` either in the inventory or excepted by name with the gate
amended; and each of the three owed measurements either green or carrying a
named repair patch.

## Patch 25.1 — No-C-Compiler Falsifier and gnu Smoke Job

**Purpose:** stand up the measurement that tracks the phase's remaining
distance, instead of asserting the endpoint at the end.

**Steps:**

- Add a CI job on an image with no C compiler installed. It is **expected-red**
  and carries its expected-failure list as tracked data, read at runtime so
  the job and the list cannot drift (O4, P7).
- **It must fail for the reason on the list.** Failing for a different reason
  is a regression and is reported as one. That is what makes an expected-red
  job a measurement rather than decoration.
- Add **one** gnu smoke job — build the compiler, run the bootstrap fixed
  point, one exec test per backend route — enumerated literally in the
  workflow, never computed (O5, P9).
- Remove `tinycc` and `clang` from `flake.nix` only when the list says nothing
  needs them; until then the removal is evidence, not cleanup.
- Document that the full suite is proved on musl only. Say it in those words.

**Exit Gate:** the no-C job exists, is non-required, fails only for listed
reasons, and its list is tracked with a successor chain; the gnu smoke job
exists with a literal subset; neither is `continue-on-error`, which has no
precedent in the repository's 153 workflows.

## Patch 25.2 — Object Determinism and the Fixed-Point Artifact Set

**Purpose:** make D4's fixed point a thing that exists before anything depends
on it.

**Steps:**

- Verify Cranelift's object output is deterministic. **If it is not, this
  patch grows the repair**; it is a prerequisite, not a footnote.
- Fix the artifact set: the objects the compiler emits for `compiler/*.gst`.
  Not runtime objects, whose reproducibility belongs to their toolchain; not
  linked executables, which would prove the linker deterministic (O7).
- Remap paths **at build time** to one pinned canonical prefix that is a build
  constant, never derived from `cwd` — a remap computed from the working
  directory reproduces the nondeterminism it exists to remove (P12).
- The comparison covers **every section the compiler emits**. Cranelift emits
  no debug info today, so that clause is currently vacuous; state it so, and
  it applies automatically when debug info appears (P11).

**Exit Gate:** the artifact set, the remap prefix and the section policy are
fixed in code; the remap prefix is a pinned constant; and **both vacuity
claims carry falsifiers that fire when they stop being vacuous** — the
debug-info one when the driver emits debug info, the remap one when a remap
appears.

**The two-build comparison moved to Patch 25.7.** It was written here first
and cannot be performed here, measured 2026-09-20:

- **No remap mechanism exists.** `REMAP_PREFIX` is pinned but nothing in
  `compiler/experiments/cranelift/src/` applies it, so comparing two builds
  would compare two unremapped builds.
- **The native route emits a linked executable, not objects.** `--backend
  cranelift -o X src.gst` produces an ELF PIE with a BuildID, `crtstuff.c`
  and `__libc_start_main` in it. O7 excludes linked executables precisely
  because comparing them proves the linker deterministic. The per-source
  objects the artifact set names exist only transiently inside that link.
- **The paths are not there yet anyway.** That artifact contains zero
  occurrences of the checkout path, so the nondeterminism the remap exists to
  remove is not observable today — the remap clause is vacuous for the same
  reason the debug-info clause is. (Narrow measurement: one small source, one
  architecture, a native backend borrowed from another worktree. Enough to
  show paths are absent here, not enough to claim it for all 898 sources.)

Patch 25.7's exit gate already reads "the native fixed point holds across two
independent builds" over "the artifact set fixed in 25.2", so the obligation
is not dropped — it is stated once, in the patch that builds the stage chain
the comparison needs.

## Patch 25.3 — The Freestanding Gust Subset

**Purpose:** define and enforce the Gust subset runtime code must be written
in, **before** any runtime file moves. Written implicitly by whoever ports
`scratch.c` first is the worst outcome.

**Steps:**

- Write the subset as a spec section. Runtime code cannot use the `str`,
  `Vector`, `HashMap` and arena it implements: no `std.Concat`, no
  `std.Clone`, no `ctx[...]`.
- **Enforce it by relocations, not by grep.** A guard that greps `.gst` for
  `std.Clone` is a name test standing in for a behaviour test — it passes for
  anything aliased or one call deep. A runtime object carrying a relocation
  against `std_*` or `os_ArenaAlloc` violated the subset however it was
  spelled (P6).
- Record that a `#[freestanding]` module attribute is the stronger answer, is
  new language surface, and is therefore an OD-register question for Phase 26
  — not needed now, which is why this stays lane work (O3).

**Exit Gate:** the subset is specified; a relocation guard enforces it and
inverts — a deliberate `std.Clone` in a runtime file fails it; and the guard
has an execution route.

## Patch 25.4 — Runtime Crate and Fixture Rehoming

**Purpose:** create the `#![no_std]` Rust crate and move the `tiny_host_*`
fixtures into it. **Before** the runtime port, not after — D3 sequenced
`fiber.c` last and O1 found the crate is needed first.

**Steps:**

- Create the crate: `staticlib`, `#![no_std]`, `panic = "abort"`, a trivial
  `#[panic_handler]`. Measured to work (P3). **Three exports here** — the
  `tiny_host_*` fixtures below. The P3 prototype also carried
  `gust_context_switch`, but that is 25.6's; requiring four at this gate
  would pull part of 25.6 forward.
- Rehome `tiny_host_add_i32`, `tiny_host_add_one_i32`,
  `tiny_host_is_positive_i32` as `#[no_mangle] extern "C"`, symbol names
  byte-identical. **Do not rewrite them in Gust**: the fixtures exist because
  the callee is foreign, and a Gust version would test Gust calling Gust and
  the contract would evaporate (O1).
- Update, in this same patch: `scripts/cranelift_registry.py:2538` (asserts
  the C path), `scripts/phase21_full_compiler_native_qualification.py:92`
  (`runtime_package.members` drops `approved_scalar_imports.o` and a second
  package appears — the record already models a static archive, so this is a
  membership change, not a new concept), `scripts/phase20_stdlib_runtime_differential.py:57`,
  and the Phase 17 `three_approved_scalar_imports` boundary sets.
- `scripts/cranelift_feature_registry.json` is edited **in place and never
  reserialized**.
- Re-run the C-toolchain provenance scan and record the delta on **#436**. The
  crate adds a second `.a` to a build that has exactly one today, and #436 is
  open on archive classification. **#436 must not be closed on a scan taken
  before the second archive existed** (P1).

**Exit Gate:** the crate builds and exports the three symbols under their
original names; every dependent guard passes against the new location with its
population re-derived rather than its row deleted; `#436` carries the new
measurement; and no registry file is reserialized.

## Patch 25.5 — Runtime to Gust

**Purpose:** move six of the eight runtime files to Gust, behind parity
evidence, in increasing order of risk.

**Steps:**

- Order: `scratch.c` (80), `strings.c` (130), `host_io.c` (60) first — 270
  lines that exercise the freestanding subset before it is trusted with the
  allocator. Then `collections.c` (243), `file_io.c` (599), and `arena.c`
  (122) last.
- `arena.c` lands behind its **no-allocate guard**: `os_ArenaAlloc` is what
  codegen emits for `ctx[...]` (`compiler/codegen.gst:692`), so a Gust
  implementation must provably never allocate. Same relocation mechanism as
  25.3.
- Each file gates on `scripts/phase17_retained_c_runtime_parity.sh`.
- **Rust is the per-file fallback.** A file that fights back drops to Rust on
  its own merits without reopening D2.
- **Decide `core_headers.h`'s fate.** Its layouts must still agree between the
  Gust side and the Rust crate; its generics macros have no consumer once
  `collections.c` is Gust. Unowned before this patch.

**Exit Gate:** six files are Gust or have a recorded reason for falling back
to Rust; parity evidence for each; the no-allocate guard inverts; and
`core_headers.h` is either retired or reduced with its remaining consumers
named.

## Patch 25.6 — `fiber.c` to `global_asm!`

**Purpose:** move the last runtime C file into the crate from 25.4.

**Steps:**

- Port **all eight** `global_asm!` blocks, preserving all four platform
  quadrants — macOS-x86_64, Linux-x86_64, macOS-aarch64, Linux-aarch64.
  Deleting by architecture would delete Apple Silicon, since macOS *is*
  aarch64, and `compiler/mir_target_authority.gst` names `darwin` as a live
  target. D6 binds the **seed**, not the runtime (O2).
- `#if` becomes `#[cfg]`; the assembly text is unchanged. `options(att_syntax)`
  for the AT&T bodies (P3).
- Keep the macOS `_gust_context_switch` / `gust_context_switch` pair explicit:
  `#[no_mangle]` applies the platform prefix to functions, but `global_asm!`
  is raw text and gets no such treatment (P4).
- Prove the port lossless: **byte comparison** of the emitted
  `gust_context_switch` and `gust_fiber_entry_wrapper` for the built quadrant;
  **text comparison**, normalised for whitespace, for the three unbuilt ones.
  Label the text half as the weaker evidence it is (P5).
- Record that three of four quadrants remain unbuilt — a pre-existing
  condition this patch must neither worsen nor silently claim to have fixed.

**Exit Gate:** `src/runtime/` contains no `.c`; all four quadrants present in
the crate; the losslessness guard passes with its two halves distinguished;
and the fiber benchmark from 25.0 has not regressed.

## Patch 25.7 — Native Stage Chain and the New Fixed Point

**Purpose:** replace the generated-C fixed point with the native one.

**Steps:**

- Build the native stage chain and establish `stage_n == stage_n+1` over the
  artifact set fixed in 25.2.
- Keep the generated-C fixed point running alongside until the native one is
  green, so a regression is attributable.

**Exit Gate:** the native fixed point holds across two independent builds; the
old fixed point still passes; both are green in the same run.

# Patch 25.7 — findings before implementation: the native fixed point already holds

Measured 2026-09-21 on the 25.5 tree, in three commands. The plan says
"replace the generated-C fixed point with the native one", which assumes
the native one has to be built. It does not.

**1. The Cranelift backend compiles the WHOLE compiler.**

    ./build/phase10-package/bin/gust --backend cranelift \
        -o /tmp/native_compiler compiler/test_runner_entry.gst

exits 0 in 94 seconds and produces an 11,008,664-byte executable. This is
not new capability — `phase21_full_compiler_native_qualification` is
`patch21_14_complete` against the same entry — but the qualification
produces MIR and objects, and what 25.7 needs is a runnable compiler.

**2. That binary IS a compiler.** `--help` prints the driver's usage, and
it compiles the compiler again.

**3. stage1 and stage2 are BYTE-IDENTICAL.**

    0b072748d4d8fd78f699e202  /tmp/native_compiler
    0b072748d4d8fd78f699e202  /tmp/native_compiler2

`stage_n == stage_n+1` over the native artifact set. That is the exit
gate's first clause, and it already passes.

**That hash is NOT a pin.** It is the value for the tree it was measured
on, and it moves whenever the compiler's own sources do — re-running the
guard after this patch's codegen change gave
`35de72c589fd1a6ec7d0c9493672799804ec2356188830531191ed00f75519a9`, and
both stages still agreed. The property is the equality, not the constant.
Quoting the number without saying so invites someone to register it as a
frozen digest, which would make every compiler change look like a
fixed-point failure.

**Verified from a CLEAN CHECKOUT**, not just from a populated build
directory: a scratch worktree with no `build/` runs
`make phase10-native-package` itself and still reaches the fixed point.
That check exists because the Phase 24 provenance guard passed locally and
failed in CI on exactly this difference — a leftover object let an earlier
resolver short-circuit — so "the guard passes" means nothing until it
passes somewhere CI-shaped.

## The one real blocker, and it is not codegen

Stage 2 fails when the stage-1 binary is run from `/tmp`:

    Native backend driver discovery error:
    sibling native backend driver path is unavailable or not executable

It fails AFTER 94 seconds of successful work — the capability decision is
`supported`, generic source-to-MIR completes — because the compiler locates
its Cranelift worker as a **sibling on disk**. Copy the binary next to
`build/phase10-package/bin/gust-native-backend` and the identical
invocation succeeds.

**CORRECTED, twenty minutes later.** I wrote here that discovery needed to
"learn a second strategy". It already has one. `mir_native_backend_discover_driver`
takes an `explicit_path` that is checked BEFORE the sibling, and it is
sourced from `GUST_NATIVE_BACKEND_DRIVER`
(`mir_native_backend_source_route.gst:691`). Measured:

    GUST_NATIVE_BACKEND_DRIVER=$PWD/build/phase10-package/bin/gust-native-backend \
        /tmp/native_compiler --backend cranelift -o /tmp/native_c3 \
        compiler/test_runner_entry.gst

exits 0 from `/tmp` and reproduces `0b072748d4d8fd78f699e202` exactly.

The compiler even prints the answer: `test_runner_entry.gst:51` says
"Set GUST_NATIVE_BACKEND_DRIVER to an absolute executable path". I read
the discovery function, saw the sibling branch fail, and concluded a
strategy was missing without reading the branch above it or the error
path's own advice. Reading the code that FAILED, rather than the code that
chooses, is what produced a wrong design conclusion from a correct
measurement.

So 25.7 needs no compiler change at all. It reduces to a script that
builds the native stage chain with that variable set, asserts
`stage_n == stage_n+1`, and runs beside the generated-C fixed point in one
CI job.

**This changes what the patch has to prove.** Two of the exit gate's three
clauses are already demonstrable: the native fixed point holds, and the
generated-C fixed point converged on this same tree tonight. The third --
both green in the same run -- is the actual deliverable, and it needs the
driver-discovery fix first or the native half cannot be scripted at all.

**Do not read the byte-identical result as "25.7 is done."** It was
measured by hand, from a package directory, with the driver already in
place. A patch has to make it reproducible from a clean checkout and
assert it in CI, and the discovery behaviour above is what stands between
those two states.

## Patch 25.8 — Release Mechanics

**Purpose:** build what D1 bootstraps from. **Before** the seed cut-over,
which has nothing to bootstrap from otherwise.

**Steps:**

- A release is an annotated tag, an artifact set, and a digest manifest. The
  **manifest, and only the manifest, is committed** as tracked text; binaries
  are release assets (O8, P15 — D1's option B says "committed binary" and is
  narrowed by P15 to "published binary, committed digest").
- The network is never on the critical path: `GUST_BOOTSTRAP_SEED=/path`,
  verified against the tracked digest.
- Declare the **N-1 floor**. Tags kept forever; one step promised. The
  published bridge binary is the permanent escape, not a transitional note
  (O9).
- Two attestation layers: the fixed-point proof, which anyone can regenerate,
  and a signed manifest for provenance. **If they conflict the fixed point
  wins** — a signature on a blob nobody can reproduce is trust, not
  verification (O10).
- Releases land through the normal ruleset. No `--admin`, no exception for
  release patches (P13).
- Mint release 0 from the current `gust_v4.c`, **before** 25.10 deletes the
  emitter.

**Exit Gate:** a release exists with tag, assets, committed manifest and
fixed-point proof; an offline build from a local seed path succeeds and
verifies against the manifest; the floor is documented.

## Patch 25.9 — Seed Cut-Over

**Purpose:** remove `gust_v4.c` — 66,002 lines, 81% of the tree's C, deleted
rather than translated.

**Steps:**

- Switch the bootstrap to obtain the previous release, with the published
  bridge binary as the fallback path.
- Delete `gust_v4.c` and every route that regenerates it.
- Invert, do not delete, the assertions that referenced it: assert its absence
  **and** the replacement route's presence.

**Exit Gate:** `gust_v4.c` is absent; a fresh checkout bootstraps from a
release and reaches the fixed point; the seed-convergence guards assert
absence plus replacement.

## Patch 25.10 — Emitter and Bootstrap Entry Deletion

**Purpose:** delete `compiler/codegen.gst`'s emitter and its bootstrap entry
**together, in one patch**. They exist only for each other: an entry with no
emitter is dead machinery, an emitter no entry can reach is #424 (D5).

**Steps:**

- Delete the emitter, `--backend bootstrap-emitter`, and the
  `GUST_BOOTSTRAP_EMITTER` authority, with their Makefile and justfile callers.
- Resolve **#446** here if it is still open: the bridge entry accepts and
  advertises `--backend mir-to-c` and `c` and discards the argument.

**Exit Gate:** no emitter, no bootstrap-emitter entry, no caller; every
removed assertion inverted; `make gust` and the native fixed point pass.

## Patch 25.11a — `cc` Optional: policy and measurement

**Purpose:** land the linker-driver policy and the measurement behind it, so
the rest of the phase has something to hold `cc` to.

Renumbered after the fact. What merged in #459 is the policy guard and D9's
measurement; 25.11's Exit Gate also requires the no-C job GREEN and the D8
expected-failure list EMPTY, and both were untrue at merge — the list had
four entries and the job is expected-red by design until 25.5, 25.6, 25.9
and 25.10 land. 25.2, 25.8 and 25.12 were each split for exactly this reason
before merging; this one was not, and merged claiming a gate it did not meet.
Recorded rather than quietly rewritten, because a merged patch whose gate was
never checked is the thing the split exists to prevent.

**Exit Gate:** `$CC` reaches the linker invocation and the check fails when
it stops; the host-native default and no-silent-fallback claims are derived
from the worker rather than asserted; and D9's musl + `rust-lld` measurement
is recorded with its gnu counterexample.

## Patch 25.11 — `cc` Optional: the gate

**Purpose:** make `cc` not required, while keeping it supported.

**Steps:**

- Prove the gate with a musl + `rust-lld -C linker-flavor=ld.lld` link in
  25.1's job. Measured to work with every C compiler poisoned; gnu is **not**
  reachable C-free with a stock toolchain (D9).
- Keep `$CC` honoured indefinitely.
- User builds default to the **host's native target**; musl is opt-in. On a
  gnu host with no C compiler the driver **probes, then errors naming
  `--target x86_64-unknown-linux-musl`** — it never silently switches, which
  would hand the user a static binary with a non-functional `dlopen` as a side
  effect of their package list (O6, P10).

**Exit Gate:** the no-C job is green; `$CC` still works; the probe-then-error
path is tested; the D8 job's expected-failure list is empty.

## Patch 25.12a — Closure Readiness Reporter

**Purpose:** measure distance to closure, so 25.12 has something to assert
against instead of an argument that the conditions hold.

Split out of 25.12 after review: 25.12's Exit Gate requires the falsifier
promoted, the closure sentence written AND `TASK.md` moved with all 127
reader scripts swept. A patch that lands only the reporter would publish
under an identity whose gate it does not meet, which is the split this
project's one-patch-one-publication rule exists to prevent.

**Steps:**

- Report each closure condition and what owes it: runtime `.c` files (25.5,
  25.6), `gust_v4.c` (25.9), emitter residue (25.10), the expected-failure
  list (25.1, 25.11), and the active-roadmap declaration (25.12).
- Every condition is derived, not asserted: a recursive scan for runtime C, a
  `git ls-files` sweep for emitter residue, the parsed `# Phase N` headings
  for the active roadmap, and the tracked falsifier list's own schema.
- **An absent input is never a satisfied condition.** A missing
  expected-failure list reads as an outstanding condition, not an exhausted
  one; an uninspectable file is not a clean file.

**Exit Gate:** the reporter names every outstanding condition with its owning
patch; each condition's check is shown to both fire and clear; and the
closure sentence is printed only when none remain.

## Patch 25.12 — Phase 25 Closure

**Purpose:** promote the falsifier and write the terminal record.

**Steps:**

- Flip 25.1's job to **required**. This is a patch, never automatic: promotion
  by a success elsewhere would turn a check red with nobody expecting it (P8).
- Write the closure sentence against what was measured. If
  `tree-sitter-gust` was excepted in 25.0, the sentence says so.
- Move this document into `TASK.md` with the Phase 24 record preserved, and
  sweep the 127 scripts that read it.

**Exit Gate:** the no-C job is required and green; the closure sentence names
its exceptions; `TASK.md` carries the Phase 25 record and every prior
immutable record still validates.

---

# Patch 25.0 — C Toolchain Requirement Enumeration · **IN PROGRESS**

Phase 25 activated by the operator on 2026-09-20. This is the phase's first
patch and the pre-work the sequence names: enumerate what actually requires
a C toolchain, **from the tree rather than from the registers**, because
Phase 24 closed on "28 registered live-C cases" and `#398`, `#422`, `#424`
and `#451` each found something the registers missed.

## The enumeration

Derived by category with a separate measurement each, rather than one
pattern. A single regex over the tree matched `as` and `cc` as substrings
inside `.gst` sources — over-approximating and then tuning until the number
looks right is how a heuristic gets mistaken for a measurement.

| category | measurement | count |
| --- | --- | --- |
| `cc` invocation sites | `phase24_c_toolchain_provenance report`, justfile now enabled (#436) | **102 invocations, 0 unresolved** |
| Makefile C compilation | `$(CC)` recipe lines | **11** |
| `tree-sitter` grammar tests | `tree-sitter test` / `parse` sites in Makefile and justfile | **2** |
| Rust linker driver | rustc defaults to `cc` on `*-linux-gnu` (D9) | every cargo link |

The 102 sites classify as: `script-authored-c` 69, `native-object` 57,
`frozen-oracle-c` 12, `layout-oracle-c` 10, `retained-runtime-c` 7,
`bootstrap-chain-c` 4, `rust-archive` 1, `toolchain-query` 1. Zero
unresolved, every site owned.

## `tree-sitter-gust` — **RESOLVED: out of scope, excepted by name**

The roadmap left this open because it is ~12,900 lines, about 16% of the
tree's C, and the `tree-sitter` CLI compiles `src/parser.c`. Measured, it is
not reachable from anything the exit gate covers:

- **`make test` does not depend on it.** `Makefile:262` reads
  `test: gust require_just`; `test_tree_sitter` is a separate `.PHONY`
  target that nothing else names as a prerequisite.
- **No workflow invokes it.** Zero matches for `tree-sitter` across
  `.github/workflows/`.
- **Reachable only by explicit opt-in** — `make test_tree_sitter`, or
  `justfile:22605 test-tree-sitter-fast-c`, which passes `CC=cc` itself.

Against D10's operational test — absent from the machine, does a
hello-world and the full suite still build and run? — the answer is yes.
The grammar is editor tooling; the compiler has its own lexer and parser in
`compiler/*.gst`.

So it is **excepted by name**, and the closure sentence must say so rather
than imply the repository contains no C. Silence here would read as
oversight at the gate, which is the failure this patch exists to prevent.

## Owed measurements

**Cranelift object determinism — MEASURED, holds.** D4's prerequisite.
`compiler-mir-ingestion-object` over the same MIR fixture:

```
3 runs, same input     -> b3022feb0a142668e0200aa9   (632 bytes each)
same input, other path -> b3022feb0a142668e0200aa9
```

Byte-identical and path-independent, so D4's fixed point over emitted
objects is well-founded and 25.2 does not grow a repair. Scope stated
honestly: one fixture, one architecture, one machine. It rules out the
cheap failure mode — embedded timestamps, addresses or input paths — not
the whole claim; O7's artifact set is the compiler's own objects, which is
a much larger surface.

Two false starts are recorded because both would have produced a *fabricated*
non-determinism result: a wrong-format fixture and a deliberately-invalid
rejection fixture, each exiting 2 with no output, on which a naive `cmp`
reports "differ". Check the artifact exists before comparing it.

**D9's poison test past `std`** and **the fiber benchmark on musl** remain
unmeasured and are still Patch 25.0 work.

**D9's poison test past `std` — MEASURED, and it found a blocker.** Linking
the *real* runtime archive with every C compiler poisoned does **not** work,
for a reason nobody had measured:

```
rustc --target x86_64-unknown-linux-musl -C linker=rust-lld \
      -C linker-flavor=ld.lld -C link-arg=build/gust-runtime-package.a
  rust-lld: error: undefined symbol: __fprintf_chk
  rust-lld: error: undefined symbol: __printf_chk
  rust-lld: error: undefined symbol: __isoc23_strtol
```

`build/gust-runtime-package.a` is compiled against **glibc** and carries
**9 glibc-specific undefined symbols** — `__printf_chk`, `__fprintf_chk`,
`__memcpy_chk`, `__isoc23_strtol`, `__stack_chk` among them. These are
glibc's FORTIFY and ISO-C23 shims; musl provides none of them.

Also recorded: `-lpthread` does not exist on musl, where pthread lives in
libc. The earlier `std`-only measurement never touched either fact.

**What this means for D9 and D9a.** The C-free musl link cannot be proved
while the runtime is C, because the runtime archive would itself have to be
rebuilt for musl — which needs a C compiler. The gate is unreachable until
the runtime stops being C.

That is not a contradiction in the plan; it is the plan's ordering being
right for a reason that had not been measured. D1 already sequences the
**runtime before the seed and before the linker driver**, on the argument
that every binary links the runtime. This is a second, independent reason
for the same order, and a sharper one: **Patch 25.11 cannot pass its own
exit gate until Patches 25.5 and 25.6 land.**

D9 stands as written — `cc` stops being required — but its proof moves from
Patch 25.0 to after the runtime port. The roadmap's step 12 already sits
there; what changes is that this is now a hard dependency rather than a
tidy ordering.

**Fiber benchmark on musl — BLOCKED by the same root cause, not run.**
Benchmarking fibers under musl means building the C runtime for musl, and
the finding above says the runtime is glibc-bound. No musl C toolchain is
installed either (`musl-gcc` absent, zero musl packages), so the benchmark
cannot be run today even by installing one without first making the runtime
musl-clean.

Recorded as blocked rather than skipped: D9a treats it as owed before the
D8 job is called performance-representative, and that obligation survives.
It moves behind the runtime port with D9's proof, for the same reason and
by the same dependency.

## What Patch 25.0 changes about the plan

Nothing in D1-D10 is contradicted. One dependency hardens:

> **Patch 25.11 (`cc` optional) cannot pass its own exit gate until
> Patches 25.5 and 25.6 land.** The runtime must stop being C before a
> C-free link is provable, because the runtime archive is glibc-bound.

And one scope question closes: **`tree-sitter-gust` is excepted by name**,
so the phase's closure sentence claims a C-free *build and test of Gust*,
not a C-free repository.

Two of three owed measurements are resolved — determinism holds, the poison
test found the blocker above. The third is blocked behind the same
dependency and stays owed.

---

# Patch 25.6 — findings before completing the port

## The port is additive today, and that is not a valid intermediate state

`fiber_asm.rs` adds all eight `global_asm!` blocks, but `src/runtime/fiber.c`
is untouched: still 719 lines, still eight `__asm__` blocks, still defining
`gust_context_switch` and `gust_fiber_entry_wrapper`. The assembly now exists
twice.

Measured: the Rust crate's *entire* public surface — the three `tiny_host_*`
fixtures from 25.4 and both fiber functions — compiles into a **single**
codegen unit object. So the two definitions are not merely duplicated in the
tree, they are duplicated in one archive:

    gust_runtime_rs-<hash>.gust_runtime_rs.<hash>-cgu.0.rcgu.o
        T gust_context_switch
        T gust_fiber_entry_wrapper
        T tiny_host_add_i32
        T tiny_host_add_one_i32
        T tiny_host_is_positive_i32

`fiber.o` is pulled from `gust-runtime-package.a` for `gust_yield`, and the
crate object is pulled for `tiny_host_*`. Both get pulled, so both sets of
definitions enter the link and it fails on duplicate symbols. The collision is
latent only because 25.4's original recipe merged all 310 members and the
archive was never exercised this way; the single-member extraction that
replaced it makes the crate object unconditionally present.

**So the deletion from `fiber.c` must land in the same patch as the addition
to Rust.** There is no green intermediate.

## `gust_yield` is the reason this patch gates 25.5

The Exit Gate already requires `src/runtime/` to contain no `.c`, so the 579
non-assembly lines were always in scope. What the entry does not convey is why
they are urgent, and Patch 25.5 measured it: **codegen emits `gust_yield()`
into every `while` loop and every recursive function**, unconditionally
(`codegen.gst:4018`, `:3870`). `gust_yield` is defined at `fiber.c:336` and is
a real scheduler function — `pthread_mutex_lock`, `sched_yield`, the shard
run-queue — not a stub.

So `fiber.c` is not "the last runtime file" in the sense of least-connected.
It is the one every compiled Gust program reaches on every loop iteration,
which is why 25.6 must precede 25.5 rather than follow it.

The hard part of this patch is therefore the 579 lines, not the 140 that are
done. `no_std` has no pthread, so the scheduler port needs either raw futex
syscalls or a libc dependency the crate does not currently take. That choice
is this patch's real subject and is not yet made.

## What 25.6 CANNOT fix, stated so it is not assumed

Patch 25.5's finding named two injected dependencies. This patch removes one
of them from C, and cannot touch the other.

`printf`/`exit` in slice bounds checks is a **codegen** property, not a runtime
one: `codegen.gst:1647`, `:1677`, `:1697`, `:2000`, `:2088`, `:2992` emit the
calls inline into every Gust function that indexes. Porting `fiber.c` to Rust
does not remove a single one of them — they are in the compiler's own emitted
output, including the compiler itself.

Clearing that needs codegen to call a runtime-provided abort instead of
inlining `printf`/`exit`, which is a change to the emitter and belongs with
whoever owns the freestanding subset, not here. Recorded because 25.5's
finding could be read as handing both problems to this patch, and only one of
them is ours.

## The 579 lines: what they need, and the `no_std` decision they force

The earlier finding said the hard part of this patch is the 579 non-assembly
lines and that the choice between raw syscalls and a libc dependency "is not
yet made". Enumerating what `fiber.c` actually calls makes the choice, and it
is not the one the crate's current shape implies.

Host surface, counted:

    pthread_mutex_lock / _unlock        40
    pthread_mutex_init / _destroy        4
    pthread_create / _join / _self       4
    pthread_setaffinity_np               1   (Linux)
    pthread_mach_thread_np               1   (macOS)
    sched_yield                          4
    malloc / free                        8
    __sync_* atomics                     4
    printf / exit                        8
    usleep, sysconf, getenv, atoi        4

Two of those groups are free. The `__sync_*` builtins map onto
`core::sync::atomic` with no libc at all, and `malloc`/`free` are only used
for the fiber struct and its stack, which a Rust port can own outright.

**The mutexes are what force the decision.** 44 of the calls are mutex
operations, and `pthread_mutex_t` is an OPAQUE type whose size and alignment
are libc- and platform-specific. Measured here: 40 bytes, align 8, on glibc
x86_64. Not measured, because no second libc is installed on this machine --
but the type is opaque precisely so that it may differ, and musl and macOS
are known to differ from glibc.

A `#![no_std]` port must therefore hand-declare that type as a byte array of
a guessed size per platform. Guess low and the mutex scribbles over adjacent
memory; guess high and it merely wastes space. Both are silent. And this
patch is committed to **all four platform quadrants** (O2, D6), three of
which are unbuilt here -- so three of the four guesses could not be checked
even in principle by this machine.

That is the argument against `no_std` for this module, and it is
structural rather than a matter of taste: the one thing 25.6 must not do is
introduce a defect that only appears on the quadrants nobody builds.

**What that means for 25.4's `#![no_std]`.** Phase 25's gate is *no C
compiler*, not *no libc* -- linking libc requires no `cc`. So using `std`,
which supplies `Mutex` and `thread` with no layout to guess, costs the phase
nothing it is trying to buy. But it does reverse a decision 25.4 recorded
deliberately, so it is stated here as a decision to be taken rather than
taken quietly in a commit that looks like a port.

The options, ranked:

  1. **Crate becomes `std`.** `std::sync::Mutex`, `std::thread`. No opaque
     layouts, all four quadrants correct by construction. Reverses 25.4's
     `#![no_std]` and `panic = "abort"` shape.
  2. **Stay `no_std`, bind pthread per platform.** Preserves 25.4, but puts
     a hand-maintained ABI table in the one file whose bugs appear only on
     unbuilt platforms.
  3. **Raw futex syscalls.** Most work, and Linux-only, so it fails O2 on
     its own.

Option 1 unless someone names a reason the crate must stay `no_std` that is
stronger than the layout hazard. The fixtures from 25.4 do not need
`no_std`; they need to be FOREIGN, which they remain either way.

## Sizing `gust_check_fail` before anyone starts it

The emitter's libc surface section above names seven `printf`/`exit` sites in
`codegen.gst` and proposes one runtime-provided noreturn to replace them.
Seven emission SITES is not seven emissions. Counted in the current seed:

    Vector bounds check failed   1960
    Slice  bounds check failed      1
    Pool   bounds check failed      1
    HashMap GetRef missing key      1
                                 ----
                                 1963 inline printf/exit pairs
                                      across 1,723 of 66,002 lines

So the change replaces **1,963 inline `printf(...); exit(1);` pairs with
1,963 calls to one function**, and removes `printf` and `exit` from emitted
code entirely — one definition remains, in the runtime, where 25.5 and 25.6
can move it to Rust along with everything else. That is the single largest
reduction available in the emitter's libc surface.

Two things the distribution tells us. Vector indexing is 99.8% of it, so a
change that handled only `Slice` would look complete and do nothing. And
`Slice` appearing exactly once confirms from a second direction what the
25.5 probe found: the compiler's own sources reach bytes through
`std.str_byte_at` (84 uses), not through `s[i]`, so slice indexing is rare
in the code the compiler compiles even though it is common in the language.

**It moves the seed** — 1,723 lines of `gust_v4.c` — so it needs a bootstrap
and should ride with a patch already paying for one rather than buying a
66,002-line republication of its own. This patch pays for one. Sized here so
that decision is made against a number instead of an impression.

## The port cannot be incremental, measured

Before writing any Rust, the obvious question is where to start. Looking for
a self-contained corner, the mutex pool reads like one: 75 lines, its own
`gust_mutex_pool`, its own lock. It is not. `std_Mutex_Lock_impl` blocks by
suspending the running fiber onto a wait queue and calling
`gust_fiber_switch` — so it needs the fiber representation, `active_shard`,
the shard's `active_fiber`, and the context switch itself.

Counting which of `fiber.c`'s twenty functions touch the shared state
(`gust_Fiber`, `gust_SchedulerShard`, `active_shard`, `gust_shards`,
`gust_num_shards`, `gust_pending_fibers`, `gust_scheduler_running`,
`gust_fiber_switch`, `gust_context_switch`, `gust_loop_ticks`):

    touch nothing shared     4   get_num_threads_to_use, std_Mutex_Alloc,
                                 std_Channel_Alloc, the entry wrapper
    touch 1-3                7
    touch 4-6                9   including both Channel primitives, both
                                 Mutex primitives, yield, spawn, the shard
                                 loop, init and destroy

Sixteen of twenty. There is no leaf to move first, because every blocking
primitive in this file blocks the same way: change the fiber's state, push it
on a queue, switch. That is not incidental coupling, it is what a
cooperative scheduler IS.

**So Patch 25.6 is one commit of roughly 719 lines, not a sequence.** Taken
with the earlier finding — that the assembly must be deleted in the same
commit that adds it, or the two definitions collide in one archive — the
whole file moves at once or not at all.

That raises the stakes on the `no_std` question rather than settling it
differently. Writing 719 lines of unsafe systems code in one commit, with
hand-guessed `pthread_mutex_t` layouts, on three platform quadrants that
cannot be built here, is not a risk worth taking to preserve a crate
attribute. `std` supplies `Mutex` and `thread` with no layout to guess, and
the phase's gate is *no C compiler*, not *no libc*.

## The fiber benchmark, measured at last — and `gust_tick` costs 26%

25.6's Exit Gate says the 25.0 fiber benchmark must not regress. That
benchmark was never built: the roadmap's own table records it as
**unmeasured**, so the gate cited an artifact that did not exist and could
not have been evaluated either way.

Built and run. A tick-dominated hot loop, 200M iterations, seven runs,
median, same machine, same `-O2`:

    pre-change compiler  (inline `--gust_loop_ticks`)   0.58 s
    post-change compiler (`gust_tick()` call)           0.73 s
                                                        +26%

About 0.75 ns per iteration, which is a non-inlined call plus a TLS access.
The two binaries differ only in the tick: same source, same runtime, one
emits two inline decrements and the other two calls.

**This is the worst case, and it should be read as one.** The loop body does
a single add, so the tick is most of the work. Real code does more per
iteration and the relative cost falls. But 26% on the pathological case is
not nothing, and it is the number the gate has to be argued against.

Why the call exists at all: `gust_loop_ticks` was a thread-local *int*, and
stable Rust cannot export a C-visible `__thread` data symbol. The counter
could not move as data, only as a function.

Three ways out, none free:

  * **Accept it.** Defensible only with evidence from realistic code, which
    this measurement is not.
  * **Inline the fast path.** Emit the decrement inline and call only when
    the tick expires — but that needs the thread-local back, which is the
    thing stable Rust cannot give.
  * **LTO across the C/Rust boundary**, so the call inlines. Plausible, and
    it changes the build rather than the language.

Recorded as a decision owed, not a detail. A 26% regression on loop-heavy
code is the kind of thing that gets discovered by a user rather than a
patch, and 25.6 cannot claim its Exit Gate clause while it stands.

### LTO does not recover it, and the regression is on a dying route

Two follow-up measurements settle the `gust_tick` question, one negatively
and one in the change's favour.

**LTO across the C/Rust boundary does nothing.** Built the crate with
`lto = true` and the benchmark with `-flto`:

    inline decrement (baseline)   0.58 s
    gust_tick(), no LTO           0.71 s
    gust_tick(), LTO both sides   0.74 s

No improvement — slightly worse. GCC's LTO and Rust's LLVM LTO are not
interoperable, so nothing inlines across the boundary. That option is
eliminated by measurement rather than by argument, which is worth more than
leaving it on the list as plausible.

**The regression is confined to the generated-C route, which 25.10 deletes.**
The preemption tick is emitted by `codegen.gst` alone. The native backend
knows `gust_yield` as a callable runtime symbol
(`main.rs:15588`, `:16649` — a `RuntimeCall` and a required-symbol entry)
but **never injects a tick into loops**. So the surviving route does not pay
this cost and never did; the route that pays it is on the deletion list.

That makes the trade defensible on its own terms: a 26% worst-case cost on
a path being removed, in exchange for the last thread-local data symbol
leaving the runtime. It should still be stated in 25.6's record rather than
discovered later, because until 25.9 and 25.10 land, the compiler itself is
built through the route that pays it.

### A pre-existing gap this uncovered: native code never preempts

If `codegen.gst` is the only emitter that injects the tick, then natively
compiled Gust has **no automatic preemption** — a fiber that loops without
calling `gust_yield` explicitly never yields. The generated-C route
preempts every `GUST_TICK_INTERVAL` iterations; the native route does not.

This is not caused by anything in Phase 25 and predates this patch. It
matters here only because Phase 25's end state is the native route, so
"cooperative scheduling works" is inherited from a path that is being
deleted. Flagged for an owner rather than fixed in a patch about `fiber.c`:
deciding whether the native backend should inject a tick is a scheduler
question, not a porting one.

## Constructing a `str` in Gust: solved, and it needed no new surface

The four `strings.c` functions left after the pure ones all need the same
thing — build a `str` from a pointer and a length — and every construction
path Gust offers (`std.Concat`, `std.Clone`, `std.str_slice`) is itself a
runtime call, which is circular when the function being written IS
`std_str_slice`.

It is not a gap. `compiler/lexer.gst:147-155` already does it:

```gust
unsafe {
    mut h  := os.ScratchAlloc(16);
    mut hp := (h + 0) as *StrHeader;      // type StrHeader struct { data: *byte, len: int }
    (*hp).data = (&s[start]) as *byte;
    (*hp).len  = end - start;
    return *(((hp as *str) + 0) as *str);
}
```

A `str` is `{ data, len }`, so a struct of that shape, a pointer cast and a
deref reconstruct one. The `unsafe` block is required — pointer arithmetic
and raw casts are rejected outside one, which is the compiler telling the
truth about what this is.

Compiled, `std_str_slice` emits
`Slice_unsigned_char std_str_slice(Slice_unsigned_char s, int start, int end)`
— byte-identical to the C — and references exactly three things:
`gust_check_fail` (injected), `os_ScratchAlloc` (layer 1, a downward call
from layer 2, legal) and itself.

**Three separate fixes from this phase had to hold at once for that to
pass**: the injected-primitive exemption, the layer order permitting
downward calls, and the narrowing that lets a module call what it defines.
Any one missing and this reads as a violation.

### One semantic difference, recorded rather than smoothed over

The C returns the slice **by value** and allocates nothing. The Gust version
took 16 bytes of scratch per call. Scratch is a bump allocator that resets,
so the cost was small, but "allocates nothing" and "allocates 16 bytes" are
not the same claim, and `std_str_slice` is called 165 times across the
compiler's own sources.

**RESOLVED 2026-09-21, and it needed no new surface either.** A struct local
— `mut hdr: StrHeader;` then field assignment — emits `StrHeader hdr` on the
stack and the return copies it out by value. Scratch was never required; the
first version reached for `os.ScratchAlloc` because that was the allocation
primitive already in hand. The port is allocation-free, like the C, so the
difference is removed rather than merely measured.

## `strings.c`: 9 of 11 in Gust, and the last two need arena bytes Gust cannot ask for

**CORRECTED 2026-09-21.** The table below was right about the destination and
wrong about the state: the file had **eight** functions, not nine.
`std_parse_int` was listed here and absent from `compiler/runtime/strings.gst`.
The sentence "All nine match" was never true when it was written — nothing
had compared them. It is true now, and checked by
`scripts/phase25_strings_gust_parity.sh` rather than asserted. See
[Deleting the runtime C](#deleting-the-runtime-c-five-files-are-free-strings-costs-a-generation)
below for what the comparison found.

Nine of `strings.c`'s eleven functions are Gust, each emitting a signature
compared against the C rather than eyeballed:

    int           std_str_eq(Slice_unsigned_char, Slice_unsigned_char)
    unsigned char std_str_byte_at(Slice_unsigned_char, int)
    unsigned char std_is_alpha(unsigned char)
    unsigned char std_is_digit(unsigned char)
    unsigned char std_is_whitespace(unsigned char)
    int           std_str_find(Slice_unsigned_char, Slice_unsigned_char)
    int           std_parse_int(Slice_unsigned_char)
    Slice_unsigned_char std_str_slice(Slice_unsigned_char, int, int)
    Slice_unsigned_char std_str_trim(Slice_unsigned_char)

All nine now match, against a frozen copy of the C rather than against
memory. `std_str_trim` calls `std_str_slice`, which the layering rule
permits only because a module may call what it defines — a narrowing made
earlier today after this exact case failed.

## Deleting the runtime C: five files are free, `strings.c` costs a generation

**The branch does not link today, and that is not a tidiness problem.**
Measured by compiling the unity build and linking it against the crate:

    cc /tmp/probe_main.c /tmp/unity.o libgust_runtime_rs.a
    multiple definition of `os_ArenaAlloc' ... first defined here
    multiple definition of `os_Arena_New'  ... first defined here
    ... 40+ more

The archive is ONE member — Patch 25.6 made it so deliberately — so pulling
in `tiny_host_add_i32` pulls in every ported function beside it. While the C
originals are still compiled into the unity build, every one of them
collides. So the deletion is what makes the branch build, and it cannot be
deferred to a follow-up patch.

### Five of the six delete without touching the seed

`arena.c`, `scratch.c`, `collections.c`, `file_io.c` and `host_io.c` have
their symbols in the archive, and the archive is already on every link line.
Removing their `#include`s changes no compiler source, so the emitted C is
unchanged and `gust_v4.c` does not move. Deletion, Makefile object rules, and
the registry rows — the shape Patch 25.6 already established when it deleted
`fiber.c` (nine files, 733 deletions).

`strings.c` must lose `std_Clone_str` and `std_str_split` in the same commit:
those two ARE in the archive, so they collide like the rest. The other nine
stay in C for one more generation.

### The ninth and the seed: why `strings.c` is different

Its remaining nine functions move to **Gust**, not to Rust, so they arrive
as emitted C inside the compiler's own translation unit. That creates an
ordering problem the other five do not have:

1. `gust_bootstrap` is built from the committed seed `gust_v4.c`. The
   current seed calls `std_str_eq` and friends and does not define them.
2. Adding `import "runtime/strings.gst"` to a compiler entry makes
   stage 1/2/3 emit the nine. While `strings.c` is still in the unity
   build, that is a duplicate definition — in the same translation unit,
   so it is a compile error, not a link one.
3. Deleting `strings.c` first leaves the old seed with no definitions.

The way through is one local bootstrap and one commit. Locally: drop the
include, add the import, and link `gust_bootstrap` against a temporary
object built from the retained `strings.c`. `make bootstrap` then
republishes `gust_v4.c` from stage 3, and the new seed contains the nine.
Commit the new seed together with the deletion and the import; a clean
checkout builds `gust_bootstrap` from the new seed, which already defines
them, so the temporary object is never needed again and is not committed.

This is the two-generation rule as a process, collapsed into one commit,
and it is the reason `strings.c` should be a separate patch from the other
five rather than riding along.

### Two Gust facts that cost a build cycle each, and one that did not

Writing the include-guard helper hit both of these in a row. Neither is
documented anywhere and neither error names its cause.

**`guard` is a RESERVED KEYWORD** (`compiler/lexer.gst:164`, token tag 27).
A local named `guard` produced ten of these:

    ParserError at 4184:9: Syntax Error: Expected valid statement inside block
    ParserError at 4184:15: Syntax Error: Expected valid statement inside block
    ... two per line, for five more lines

The message names neither a keyword nor the right line — the parser loses
sync and then fails on everything after it, so the first error is below the
cause, not at it. A four-line repro found it in one run; reading the errors
where they appeared would not have.

**A function cannot RETURN a `std.Concat` result.**

    Semantic Error: Escape analysis violation.
    Returning scratchpad-allocated view of type Str

`std.Concat` allocates in scratch, and scratch cannot escape its frame.
This kills the obvious shape — a small helper that builds a string and
returns it — as a DESIGN, not just as written. The way through is the one
the surrounding code already uses: accumulate into a local the caller
already owns and push that. `std_str_slice` hit the same wall earlier in
this patch and a stack local was the answer there too, so it is worth
stating as a rule: **in Gust, build strings into a caller-owned local, do
not return them from helpers.**

**And one that turned out fine:** `#` in a string literal is legal.
`codegen.gst` never emitted one before this patch, which looked like
evidence of a lexer limitation, but a `mir_memory_access` lowering
module already writes `"#include <stdint.h>\n"` at line 69. Absence of a pattern is not
evidence it is forbidden — checking took one grep and would otherwise have
produced an elaborate workaround for a problem that does not exist.

### Wiring `strings.gst` in: three assumptions tested, two survived

The last step of 25.5 is making the nine Gust functions reach every
compiled program, not just the compiler. Programs are built as
`cat src/runtime.c program.c`, so once `strings.c` goes they have no
definitions. Three things had to be true for the cheap answer to work.

**1. The emitter can emit a module with no `main`.** TRUE, and it was not
obvious — every other use of `--backend bootstrap-emitter` in this repo
names a program entry. `compiler/runtime/strings.gst` emits 314 lines
containing all nine functions, the `std_str_bounds_fail` helper, and no
`main`. Deterministic: two emits are byte-identical.

**2. That output compiles inside the runtime translation unit.** TRUE.
`core_headers.h` + the emitted module compiles with zero errors and zero
redefinition warnings, exporting 16 `std_*` symbols. The emitter's own
preamble says *"Builtin slice structs are runtime-owned in
src/runtime/core_headers.h"*, so it already expects to coexist.

**3. It can be concatenated in FRONT of an emitted program.** **FALSE**,
and this is the blocker:

    cat core_headers.h strings_module.c program.c | cc
    error: redefinition of `struct APIRequest'
    error: redefinition of `struct SessionNode'

`APIRequest` and `SessionNode` are BUILT-IN structs, registered in
`compiler/typechecker.gst:7742` and emitted unconditionally into every
program. So the runtime prelude and the program each define them and the
concatenation that has worked since the beginning stops working. Nothing
about the Gust port causes this; it is a property of the emitter that only
shows up the first time two emitted units are concatenated.

**Three ways out, in order of preference:**

  1. **Guard the built-in struct emission** with `#ifndef` /
     `#define` per struct. Three lines per built-in, local to codegen,
     and it makes emitted C concatenation-safe in general rather than
     just for this case. Moves the seed — but this step needs a bootstrap
     anyway, so it rides along at no extra cost.
  2. **Emit built-ins only when referenced.** Correct, and strictly
     better, but it is a reachability analysis in codegen and a much
     larger change than this patch should carry. Worth its own patch.
  3. **Post-process the generated module** to strip the duplicate struct
     definitions. Cheapest and worst: fragile text surgery over generated
     C, which breaks silently the next time the emitter's layout changes.

Recommending 1, with 2 recorded as the follow-up it deserves.

**Two tests depend on those built-ins** —
`compiler/codegen_initializer_test_entry.gst` and
`compiler/typechecker_templates_test_entry.gst` — so option 2 cannot
simply delete them from the prelude, and option 1 must keep the
definitions, only guard them.

**The generated file is a second seed, and should be named one.** It has
to be checked in: `gust_bootstrap` is built from `gust_v4.c` plus
`src/runtime.c`, and generating the strings C needs a compiler, so a
build-time rule is circular. Checked in and regenerated by a guard that
diffs, exactly as `gust_v4.c` is. That is a real cost to state plainly —
314 lines of transpiled C in the tree, which will churn whenever the
emitter's preamble changes — and it is the reason Patch 25.9 exists.

### The deletion's registration surface, measured before starting it

Deleting five `.c` files is not five deletions. The archive's shape and the
runtime's source inventory are asserted in eight places, and every one of
them names files by path:

| what | where | shape |
| --- | --- | --- |
| unity build | `src/runtime.c` | five `#include`s |
| object list | `Makefile` `PHASE21_RUNTIME_OBJECTS` + 5 `.o` rules | delete the rules, do not leave them dangling |
| archive members | `scripts/cranelift_feature_registry.schema.json` and the registry | `members` array, exact |
| archive members | `scripts/phase21_full_compiler_native_qualification.py` | compares `ar t` output exactly |
| archive members | three `phase21_*_native_source.sh` guards | fallback member lists |
| helper sources | `scripts/phase17_opening.py` `required_sources` | a SET compared for equality |
| helper rows | `scripts/cranelift_feature_registry.json` `source_path` | **57 rows**: arena 10, host_io 8, file_io 26, scratch 6, collections 7 |
| a guard that COMPILES one | `scripts/phase17_retained_c_runtime_parity.sh` | `cc -O2 -c src/runtime/arena.c` |

The last two are the ones that make this a patch rather than a chore. The
57 rows are per-helper provenance, so they move to the Rust crate rather
than disappearing, and `phase17_retained_c_runtime_parity.sh` builds
`arena.c` directly — a guard whose whole subject is the retained C runtime
has to be rescoped, not deleted, under the invert-don't-delete rule.

`phase17_opening.py`'s `required_sources` still names `fiber.c` and
`approved_scalar_imports.c`, both already deleted, so that guard is red on
this branch before this patch touches anything. Control it against the
branch base before reading any failure there as new — #457 is the fix in
flight.

Patch 25.6 did this for one file and it was nine files and 733 deletions.
Five files with 57 provenance rows is the same shape at five times the
width, which is why it is its own commit and not a tail on the ports.

### A stale-archive bug in the build graph, and the same one in the harness

    $(PHASE25_RUNTIME_RS): src/runtime-rs/src/lib.rs src/runtime-rs/Cargo.toml

The crate now has six source files. Editing `file_io.rs` or `collections.rs`
does not make `make` rebuild the archive, so a build links yesterday's
runtime and passes. The identical bug was in
`scripts/phase25_runtime_rs_abi_smoke.sh`, which skipped the rebuild when an
archive already existed — a harness reporting green about code it had not
compiled. Both are fixed; the pattern is worth naming because both were
written by someone (me) who had just been careful about everything else in
the same file.

### `file_io.c`: four places where the faithful port is not the obvious one

- **`os_System` returns the RAW wait status.** `exit 3` is 768. Returning
  `WEXITSTATUS` would read as a fix and would silently change every caller
  doing arithmetic on the result. Pinned by a test that says so.
- **`os_ReadDir` must keep yielding `.` and `..`.** `std::fs::ReadDir`
  filters them. Swapping it in would change what the runtime returns and
  would look like simplification — so this reads `d_type` and `d_name` out
  of a hand-declared `struct dirent`, which is exactly the layout-guessing
  trap P17 named. Paid for rather than assumed: `abi_smoke.c`
  `_Static_assert`s the offsets against the real header AND walks a real
  directory. Off Linux the layout cannot be checked from this lane (Darwin
  has an extra `d_namlen`; x86_64 Apple uses `readdir$INODE64`), so
  non-Linux takes the `std::fs::ReadDir` path with the divergence stated in
  the code rather than a second guess.
- **Paths truncate at an interior NUL; contents do not.** `CString` would
  have turned a truncation into a new error path.
- **`os_path_join`'s hardcoded `a/b` + `../../c` -> `../c` CONTRADICTS its
  own rules.** The general algorithm gives `c`, and the neighbouring input
  `../../d` still gives `d`, so the override is one input wide and probably
  encodes a wrong fixture. Both inputs are pinned so it cannot be tidied
  away silently. Worth an explicit ruling in a later patch; it is not a
  porting decision.

### What `s[i]` actually emits, since the earlier note was wrong

`s[i]` does **not** emit a bare `s.data[i]`. Measured in the emitted C:

    (*({ if (i < 0 || i >= s.len) { gust_check_fail("Slice bounds check failed", __LINE__); } &(s.data[i]); }))

So the Gust ports never lost the bounds check. What they lost was the
DIAGNOSTIC — stderr and a generic message where the C printed a
function-specific one to stdout — and, in `std_str_slice`, the check was
answering a different question: `start >= s.len` where the C asked
`end > s.len`. That let the over-long slice through and rejected the empty
tail slice, which is legal and common. Both are fixed and both are pinned
by the abort half of the parity harness.

### The two that do not port, and why

`std_Clone_str` and `std_str_split` both need to allocate **N raw bytes
from a caller-supplied arena**. Gust cannot express that.

Measured: `os.ArenaAlloc` in Gust takes ONE argument, the allocator, and
the typechecker rejects a second — "os_ArenaAlloc expects exactly 1
argument (the allocator variable)". Gust allocates by TYPE, through
`ctx[T]`, and codegen turns that into the two-argument C call with a
`sizeof`. There is no Gust spelling for "give me 47 bytes from this arena".

`os.ScratchAlloc` does take a byte count (`register_fn(env,
"os.ScratchAlloc", p_int, ...)`), which is why `std_str_slice` works — it
needs 16 bytes of scratch for a header. Scratch and arena are not
interchangeable: scratch resets, and a cloned string must outlive the
current scope, which is the whole point of taking the arena parameter.

So the gap is specific and small: **a byte-count arena allocation**. Three
ways out, in order of preference:

  1. **Leave both in the runtime crate**, in Rust, beside the fixtures. D2
     already allows Rust as the per-file fallback "on its own merits", and
     two functions needing raw allocation is a merit.
  2. **Add a byte-count arena builtin** to match `os.ScratchAlloc`. New
     language surface, so an OD-register question under O3's rule.
  3. Have them call a C or Rust helper for the allocation and stay Gust
     otherwise — which is option 1 with extra steps.

Recommending 1. It keeps the language honest — `ctx[T]` is a typed
allocator and raw byte allocation is a different operation — and it costs
nothing the phase is trying to buy, since the runtime crate is where the
non-Gust remainder was always going to live.

---

---

# Patch 25.6 — two guards that were already red on main

## What happened

Patch 25.6 edits `compiler/codegen.gst`. Two stdlib-lane workflows are
path-filtered on that file, so this patch is the first thing in weeks to fire
them, and both failed:

    guard-stdlib-s1-str-surface
    guard-stdlib-s1-collection-receivers

## They fail identically on main, measured

Run on a worktree at `main@8acfc3f3`, the same script, the same fixtures:

    tests/test_str_surface_regression.gst        line 25, exit 1
    tests/test_hashmap_reference_receiver.gst    line 24, exit 1

Both print, byte for byte, the diagnostic they print on this branch:

    decision=deferred capability=phase13_generic_source_to_mir
    reason_code=deferred_p13_parameter_argument_target_dependent_abi
    Cranelift backend selection is valid, but the source-level route is
    not connected yet.

So this patch did not break them. It made CI look.

## Why nobody knew

`str-surface` last succeeded on main on **2026-08-20**.
`collection-receivers` last succeeded on main on **2026-09-10**.

Every run since has been cancelled by a subsequent push, and neither
workflow fires unless `compiler/codegen.gst` or `compiler/typechecker.gst`
changes. Main has absorbed the Phase 24 closure and Patches 25.0 through
25.4 in that window with these two guards never executing.

## The mechanism

`scripts/run-gust-file.sh` is cranelift-only. Its own comments say the
MIR-to-C arm is gone -- "there is no longer a compiler invocation to reach".
Both fixtures take a `&Arena` parameter and return `str`, which the native
route defers as a Phase 13 target-dependent-ABI capability. They used to
reach a fallback; Phase 24's backend removal took it away and left two
guards that cannot compile their own fixtures.

That is a Phase 24 residue of the kind `#398` and `#424` name: a consumer
left pointing at a route that no longer exists.

## What this patch does NOT do, and why

It does not repair them. Three options were weighed:

**Restore a fallback in `run-gust-file.sh`.** Around thirty scripts and four
justfile recipes call it. A fallback that fires on a deferred capability
would silence a genuine native-route regression in any of them, and the
instrument is shared across lanes. Measured first: the five guards that
assert the deferral diagnostic read it from their own compile logs, not from
this script, so they would NOT break -- but that only makes the change
possible, not safe.

**Point the two recipes at the bootstrap emitter,** the route the test runner
already uses for all 311 tests. This restores what they measure, because
neither guard is about the native route: one pins the observable values of
`str`, the other pins HashMap lowering through a reference. But it changes
which route a stdlib-lane guard exercises, and that is the stdlib lane's
judgement, not this patch's.

**Leave them red and say so.** Chosen. Neither check is in the required set
-- the `Protect main` ruleset requires exactly one, `Codex / Trusted actor` --
so they do not gate a merge. What they do is tell the truth about a part of
the tree that has been broken for between eleven days and a month.

Recording this rather than repairing it is deliberate. Making a red guard
green by changing what it measures is how a suite stops being evidence, and
Patch 25.11 has already had to be renumbered once in this phase for claiming
an Exit Gate that was not met.
