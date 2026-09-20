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

- [ ] Patch 25.0 — C Toolchain Requirement Enumeration
- [ ] Patch 25.1 — No-C-Compiler Falsifier and gnu Smoke Job
- [ ] Patch 25.2 — Object Determinism and the Fixed-Point Artifact Set
- [ ] Patch 25.3 — The Freestanding Gust Subset
- [ ] Patch 25.4 — Runtime Crate and Fixture Rehoming
- [ ] Patch 25.5 — Runtime to Gust
- [ ] Patch 25.6 — `fiber.c` to `global_asm!`
- [ ] Patch 25.7 — Native Stage Chain and the New Fixed Point
- [ ] Patch 25.8 — Release Mechanics
- [ ] Patch 25.9 — Seed Cut-Over
- [ ] Patch 25.10 — Emitter and Bootstrap Entry Deletion
- [ ] Patch 25.11 — `cc` Optional
- [ ] Patch 25.12 — Phase 25 Closure

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

**Exit Gate:** two independent builds from different directories produce
byte-identical objects for the named artifact set; the remap prefix is a
constant; and if determinism holds only after excluding sections, those
sections are named and the fixed point is recorded as the narrower one.

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

## Patch 25.11 — `cc` Optional

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
