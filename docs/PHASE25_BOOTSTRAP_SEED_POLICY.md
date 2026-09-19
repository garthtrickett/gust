# Phase 25 — bootstrap seed policy

`docs/ROADMAP_TAIL.md` §Phase 25 lists *decide how bootstrap binaries are
produced and verified* as work, not as an open decision. This is that
decision, its alternatives, and the ordering it implies. Status and scope for
the phase stay in the tail; this file carries the reasoning, so the tail stays
a summary.

Decided 2026-09-19, after `#398` closed Phase 24's backend retirement.
**Full C removal remains the separate policy decision the tail already names**
— see *What this does not decide*.

## The decision

**Bootstrap from the previous release (option A), with a verified checked-in
binary (option B) as the bridge. Do the runtime before the seed.**

## What the measurement changed

Three facts about the tree at `bae85510` shape this more than any general
bootstrapping argument.

**Rust is already a hard build dependency.** The Cranelift backend is a cargo
crate under `compiler/experiments/cranelift/`, built by `Makefile:181`. So
"remove C" was never "remove the second toolchain"; that boundary was crossed
before Phase 25 opened. An option is not disqualified for needing cargo.

**The seed is one of three C strands, and it is not the cheapest.**

| strand | what | size |
|---|---|---|
| seed | `gust_v4.c`, the compiler as generated C | 66,002 lines |
| runtime | `src/runtime.c` + `src/runtime/*.c`, hand-written, linked into every binary | 1,968 lines |
| linker | `cc` as the linker driver, Patch 18.7 | — |

**There is no release infrastructure.** No releases, no publish workflow; the
only release-named workflow is an audit.

## Options

**A — bootstrap from the previous release.** No seed in the repository; the
build obtains the last released compiler. What Go and Rust do.

**B — checked-in native binary.** A prebuilt `gust` per platform, committed.

**C — checked-in Cranelift object or archive.** `.o`/`.a` rather than an
executable.

**D — generated Rust seed.** Emit the compiler as Rust and `cargo build` it:
text, and the toolchain is already required.

**E — tiny auditable subset compiler.** A minimal Gust-subset compiler small
enough to read, which builds the real one. The Mes / live-bootstrap model.

## Ranking

| | option | assessment |
|---|---|---|
| 1 | **A** | Removes the seed rather than translating it. The fixed point survives intact: the released compiler builds current source, and current source rebuilds itself byte-identically. Today's `gust_v4.c` can mint the first release, giving a clean one-time cut-over. The cost is release infrastructure this project wants regardless. |
| 2 | **B**, *if the fixed point proves it* | The usual objection is that a blob cannot be diffed. This repository already has the machinery that answers it: require the committed binary to rebuild itself byte-identically from source. That makes the seed **verified rather than trusted**, which is most of what auditability buys. Cost: one artifact per platform. |
| 3 | **C** | Strictly worse than B — still opaque, still per-platform, and still needs a linker, with no compensating advantage. |
| 4 | **D** | Attractive at first glance: text, diffable, toolchain already present. But it is not swapping an emitter, it is **writing a new backend**, and it ends in a 66k-line generated artifact again in a different language. High cost, little gain over A. |
| 5 | **E** | Right in principle, wrong for now. Needs a defined language subset and is plausibly years of work. Recorded so it is not foreclosed. |

## Ordering: the runtime first

The ordering matters more than the choice.

The runtime is 1,968 hand-written lines across eight files, it involves no
emitter, and **every binary links it — including whatever replaces the seed**.
Left until last, each seed option inherits a C dependency it cannot shed, and
the phase's exit gate stays out of reach no matter which seed lands. It is
also the cheapest of the three strands to finish, which makes it the natural
first patch rather than the last.

So: **runtime → seed → linker driver.**

## What this does not decide

**Whether `cc` survives as the linker driver.** Patch 18.7 established it
deliberately (`compiler/mir_target_authority.gst:660-665`) and `#401` defends
it by name. "No host C compiler" may honestly resolve to *no host C compiler,
but still a linker*. That is a policy decision for the operator, and it should
be settled **before** the phase writes its closure sentence rather than
discovered at the gate — which is the trap Phase 24 fell into and spent five
patches climbing out of.

## First step, before any of the above

**Enumerate what actually requires a C toolchain, measured rather than
inherited.**

Phase 24 closed on "28 registered live-C cases". The number was accurate about
the registers and incomplete about the tree: `#398` found four further Stdlib
guards reaching the backend through `GUST_RUNNER_ROUTE` or through rows every
census projects away. The bootstrap chain has the same shape — components that
need a C toolchain without spelling `cc`. An enumeration that starts from the
existing registers will inherit the same blind spot.

---

# Remaining Phase 25 decisions

Worked through 2026-09-19 against `bae85510`. The seed decision above is D1.
Each entry says who decides: **lane** means this is ordinary lane work and is
decided here; **operator** means it is policy and is not decided here.

## D2 — the C runtime's disposition · *lane* · **DECIDED: rewrite in Rust**

1,968 hand-written lines across eight files, linked into every binary.

**The obvious answer is blocked.** Rewriting it in Gust needs gated raw
pointers, explicit FFI ownership and ABI layout enforcement — and those are
**Phase 26.1**, after this phase. `arena.c` is pointer arithmetic and
`fiber.c` is context switching; neither is expressible in Gust today.

**Declaring it a foreign component does not satisfy the gate.** The exit gate
excepts *optional* foreign-runtime components. This runtime is mandatory —
every binary links it — so the escape clause does not reach it. That is worth
stating because it is the tempting shortcut.

So: **Rust.** `cargo` is already a hard dependency, Rust expresses everything
these files do including inline assembly, and it unblocks the gate without
waiting for Phase 26. It also does not foreclose a later Gust rewrite; C→Rust
now and Rust→Gust after 26.1 are compatible.

Risk: this is a real rewrite of arena and fiber semantics, not a translation.
`scripts/phase17_retained_c_runtime_parity.sh` already exists as a comparison
harness and should gate each file.

## D3 — `fiber.c` specifically · *lane* · **DECIDED: Rust with `global_asm!`**

719 lines carrying **eight blocks of inline assembly** for context switching,
plus pthread. The riskiest single file in D2 and the one most likely to be
argued into the "foreign component" bucket. It should not be: Rust supports
`global_asm!`/`asm!` directly, so the assembly ports as assembly. Sequence it
**last** of the eight, behind the files with cheaper parity evidence.

## D4 — the form of the fixed point · *lane* · **DECIDED: compare emitted objects**

Today's proof is `stage2.c == stage3.c`, byte-identical *text*. Natively the
equivalent is comparing **Cranelift-emitted object files**, not linked
executables: linking introduces ordering and layout the compiler does not own,
so a binary comparison would be proving the linker deterministic rather than
the compiler self-reproducing.

**This depends on a fact nobody has checked: that Cranelift's object output is
itself deterministic.** Verify before adopting; if it is not, that is a
prerequisite patch, not a footnote.

## D5 — when the emitter is deleted · *lane* · **DECIDED: one patch, after the native chain is green**

`compiler/codegen.gst` is 4,765 lines; `--backend bootstrap-emitter` and its
`GUST_BOOTSTRAP_EMITTER` authority appear 6× in the justfile, 6× in the
Makefile and 3× in the compiler entry. `TASK.md` already sequences the
deletion after the native bootstrap replaces it.

What is decided here is that the emitter and the entry go **together, in one
patch**. They exist only for each other: an entry with no emitter is dead
machinery, and an emitter no entry can reach is the dead code #424 was filed
about.

## D6 — platform scope of the seed · *lane* · **DECIDED: exactly what CI builds, named**

CI is **`ubuntu-latest`/`ubuntu-24` only — 261 jobs, no macOS runner** — yet
`fiber.c` and `file_io.c` carry ten `__APPLE__`/`mach_` branches. So the tree
has macOS code that nothing builds or tests.

The seed must therefore name its platforms explicitly rather than implying
portability it has no evidence for. A seed supporting one platform while the
docs imply several is Phase 24's count problem again: accurate about the
register, incomplete about the tree. If macOS is meant to be supported, that
needs a runner before it needs a seed.

## D7 — what "independently auditable" requires · *lane* · **DECIDED: two conditions**

The tail requires preserving an independently auditable bootstrap chain, and
never says what that means. It means: **(a)** every bootstrap input is either
tracked text or an artifact whose reproduction is proved, and **(b)** a third
party can reproduce the fixed point from source alone. Concretely, each
release publishes the seed digest and the fixed-point proof.

This is what makes option B's checked-in binary acceptable at all — it is the
difference between *verified* and *trusted*.

## D8 — Nix and CI images · *lane* · **DECIDED: a no-C-compiler job is the gate's falsifier**

`flake.nix` currently ships **both `tinycc` and `clang`**, plus `stdenv.cc`.

Removing them is not incidental cleanup — it is the evidence. The gate says a
clean machine builds and tests Gust without invoking a C compiler, and the
only honest falsifier for that is **a CI job on an image with no C compiler
installed**. Stand that job up early and let it stay red; it measures the
phase's remaining distance instead of asserting the endpoint at the end.

## D9 — does `cc` survive as the linker driver? · **operator**

Patch 18.7 established it (`compiler/mir_target_authority.gst:660-665`) and
`#401` defends it by name. Cranelift emits objects; something still links
them. "No host C compiler" may honestly resolve to *no host C compiler, but
still a linker*.

Settle it **before** the closure sentence is written. Phase 24 discovered its
equivalent at the gate and spent five patches recovering.

## D10 — what counts as an "optional foreign-runtime component"? · **operator**

The exit gate excepts them and nothing defines them. This is the tail's own
"full C removal is a separate policy decision", made concrete.

One input to that decision is already settled by D2: **the runtime does not
qualify**, because it is mandatory rather than optional. Without a definition,
the exception is an escape hatch wide enough to pass the gate with the C
still in place — which is exactly the shape of defect Phase 24's narrowed
closure sentence existed to avoid.

## Sequence implied by the above

1. Enumerate what actually requires a C toolchain, measured (pre-work, stated above).
2. Stand up the no-C-compiler CI job as the standing falsifier (D8).
3. Verify Cranelift object determinism (D4 prerequisite).
4. Runtime to Rust, file by file behind parity evidence, `fiber.c` last (D2, D3).
5. Native stage chain and the new fixed point (D4).
6. Seed cut-over (D1).
7. Delete the emitter and its entry together (D5).
8. Linker-driver disposition, once D9 is answered.
