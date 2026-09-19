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

**Superseded — see D9.** This section originally left the linker driver open
as an operator policy call, on the grounds that Patch 18.7 established `cc`
deliberately (`compiler/mir_target_authority.gst:660-665`) and `#401` defends
it by name. D9 answered it by measurement instead: `cc` was only ever a
default behind `$CC`, and a C-free link was demonstrated end to end. What
survives as policy is the narrower D9a — whether the link may rely on libc
development files or must be self-contained. That still wants settling
**before** the phase writes its closure sentence rather than at the gate,
which is the trap Phase 24 fell into and spent five patches climbing out of.

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

## D2 — the C runtime's disposition · *lane* · **DECIDED: Gust is the default target; Rust is the per-file fallback**

1,968 hand-written lines across eight files, linked into every binary.

**This row has been wrong twice and the corrections are the useful part.**

*First draft:* "Gust is blocked by Phase 26.1." False. `docs/ROADMAP_TAIL.md:196`
says 26.1 **completes** gated raw pointers and FFI, not that it introduces
them. Gust has bodyless `extern func f(a: int) int;` FFI, unsafe-gated at the
call site, with aggregate returns working, raw pointers with provenance and
`*p` deref, and 1,416 `unsafe` sites in `compiler/*.gst`.

*Second draft:* "Rust on sequencing grounds", resting on three constraints.
**Two of the three are false, measured:**

- ~~"`os_Arena`'s layout is matched by name and Gust has no layout control."~~
  Gust **has `repr(C)` and `packed`**, parsed at `compiler/parser.gst:1021-1083`
  and plumbed through `compiler/ast.gst:89-90`,
  `typechecker.gst:8362` (`env_register_struct_layout_metadata`),
  `typechecker.gst:10410` (`env_struct_is_repr_c`) and the whole
  `mir_struct_layout` / `mir_layout_authority` family. This was the one 26.1
  item claimed to bite, and it does not.
- ~~"Symbol names are compiler-known, so the runtime's exports cannot be
  reproduced."~~ `extern_symbol_name` exists (`parser.gst:1559-1562`,
  `codegen.gst:785-786`), so a Gust definition can emit `os_ArenaAlloc` or
  `std_str_eq` under exactly that name.
- **"A Gust runtime sits inside the bootstrap circle."** True, but weaker than
  it was written. The fixed point already cannot detect a *consistent*
  miscompile of the compiler — that is the Thompson property and it predates
  this question. Adding the runtime does not change what the fixed point
  proves; it adds a second suspect when the fixed point *fails*. And the new
  Gust runtime is always built by the **previous** compiler-and-runtime, so
  the circle closes only after the replacement is proved, exactly as in any
  self-hosting step.

### What actually remains

Per-file, measured by what each file calls:

| file | lines | needs | verdict |
| --- | --- | --- | --- |
| `approved_scalar_imports.c` | 15 | nothing | **delete** — `tiny_host_add_one_i32` and two siblings, fixtures only |
| `host_io.c` | 60 | `malloc` `memcpy` `strlen` | Gust |
| `scratch.c` | 80 | `memset` | Gust |
| `strings.c` | 130 | `memcpy` | Gust — `std_str_eq`/`find`/`byte_at` are pure byte loops |
| `collections.c` | 243 | `memcpy` `memset` + C preprocessor macros for generics | Gust — real generics beat `core_headers.h:233`'s macro |
| `file_io.c` | 599 | stdio + pthread mutex | Gust, via `extern func` |
| `arena.c` | 122 | `malloc` `free` `memset` | Gust, **behind a guard** — see below |
| `fiber.c` | 719 | **8 `__asm__` blocks** + pthreads | **not Gust** — see D3 |

Three real obligations, none of them a Phase 26 language feature:

1. **The freestanding subset is undefined.** This is the strongest remaining
   argument and it is not one of the three above. The runtime *is* `str`,
   `Vector`, `HashMap` and the arena, so runtime code cannot use them: no
   `std.Concat`, no `std.Clone`, no `ctx[...]`. That subset — raw pointers,
   scalars, loops, `extern func` — plausibly exists and is usable, but
   **nothing defines or enforces it**, so a stray `std.Clone` in a runtime
   file would compile and recurse. Define the subset and give it a guard.
   This has value beyond the runtime; it is most of what option E wanted.
2. **`os_ArenaAlloc` must provably never allocate.** A *guard*, not a
   language feature: compile it and assert the emitted object carries no
   relocation against the allocator. Cheap, and it inverts cleanly.
3. **`fiber.c` has no Gust spelling.** See D3.

### The decision

**Gust is the default target for the seven; Rust is the per-file fallback.**

Going C→Rust→Gust is the same rewrite twice, with the same parity evidence
twice, and it ends with the runtime, the backend and the linker all owned by
Rust — a weaker self-hosting story than the one Phase 25 exists to
strengthen. Going C→Gust is one migration and ends more self-hosted.

The risk of pulling runtime-in-Gust work into Phase 25 is managed by the fact
that this is file-by-file behind parity evidence either way
(`scripts/phase17_retained_c_runtime_parity.sh`). A file that fights back
falls back to Rust on its own merits without re-opening the row. Order the
easy ones first — `scratch.c`, `strings.c`, `host_io.c` — so the freestanding
subset is exercised on 270 lines before it is trusted with the allocator.

**Declaring the runtime a foreign component does not satisfy the gate** under
either target. The gate excepts *optional* foreign-runtime components; this
runtime is mandatory, so the escape clause does not reach it. Worth stating
because it is the tempting shortcut.

## D3 — `fiber.c` specifically · *lane* · **DECIDED: Rust `global_asm!` now; module-level `global_asm` in Gust is the Phase 26 successor**

### What the eight blocks actually are

They are **not inline assembly**. They are top-level `__asm__()` blocks
containing pure `.text`/`.global` assembly with no operand constraints, no
clobber lists and no interaction with surrounding C. They define whole
functions. There are only **two of them**:

| function | size | variants |
| --- | --- | --- |
| `gust_context_switch` | ~13 instructions | x86_64 + aarch64 × underscore-prefixed (macOS) and plain (Linux) |
| `gust_fiber_entry_wrapper` | 4 instructions | same four |

2 functions × 2 architectures × 2 symbol conventions = the eight blocks. This
matters for every route below: what has to move is ~34 instructions of
standalone assembly text, not a body of C to reimplement.

### Two routes are dead, measured

**`swapcontext`/`makecontext` — rejected.** This was the route this document
was most enthusiastic about one revision ago, and it conflicts with D9.
**musl exports zero ucontext symbols:**

```
$ nm -g .../x86_64-unknown-linux-musl/lib/self-contained/libc.a \
    | grep -cE " T (swap|make|get|set)context"
0
```

D9 measured that musl + `rust-lld` is the **only** configuration that links
with no C compiler. So `swapcontext` and the Phase 25 exit gate are mutually
exclusive: taking this route means the gate is unreachable. That is decisive
before performance is even discussed — and on performance it is also bad,
since glibc's `swapcontext` issues a `sigprocmask` syscall on every switch,
against a register-only save/restore here. Recorded at length because the
conflict was between two rows in this same document and was not noticed until
both were measured.

**"Declare fibers an optional foreign-runtime component" — rejected.** D10
makes this look available. It is not: `compiler/codegen.gst:3810` emits
`gust_scheduler_spawn(8388608, gust_user_main, NULL)` into the **program
entry point**, so every Gust program's `main` runs on a fiber and every
binary links the scheduler. There is no configuration in which this is
optional.

### The ranking

**1. Rust `global_asm!` — do this in Phase 25.**

Because the blocks are standalone assembly, this is a **copy-paste, not a
rewrite**: the same ~34 instructions move from a C file to a Rust file
unchanged, and `phase17_retained_c_runtime_parity.sh` proves it. About as low
as migration risk gets.

The objection previously recorded here — "it keeps a mandatory Rust component
in an otherwise-Gust runtime" — **is already paid for and should not have
been scored as a cost.** After D9 the C-free link *is* the Rust toolchain
(musl + `rust-lld`), and the backend is already a cargo crate. Rust is a hard
build dependency of Gust either way, for the compiler and for every user
program Gust links. A `#![no_std]` crate holding two `global_asm!` blocks adds
no dependency and no new *kind* of dependency. This is what flipped the
ranking.

**2. Module-level `global_asm` in Gust — the successor, Phase 26.**

The right long-term answer, and smaller than "add inline assembly to Gust"
suggests. What is needed is **global** asm, not **inline** asm: no operand
constraints, no clobbers, no interaction with the register allocator — just
"emit this text at this symbol in `.text`". That is a fraction of the feature.

The open design question is not the syntax but the **assembler**: Cranelift
has none, so either Gust bundles one, or the feature accepts pre-assembled
bytes with the assembly text kept as pinned, auditable source. That is a real
Phase 26 decision and it is not Phase 25's to make.

Sequencing it after route 1 is close to free, and this is the rare case where
doing it twice genuinely is cheap: **the artifact that moves the second time
is the identical assembly text**, not a reimplementation. The C→Rust→Gust
objection that flipped D2 does not apply here, because there is no second
rewrite — only a second move.

**3. Add full inline assembly to Gust — not needed.**

Kept only to record that it was considered and is a larger feature than the
problem requires. Nothing in `fiber.c` uses operand constraints or clobbers.

Sequence `fiber.c` **last** of the eight regardless, behind the files with
cheaper parity evidence.

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

## D9 — does `cc` survive as the linker driver? · *lane* · **DECIDED: it stops being required; it does not stop being supported**

Asked as policy, answered by measurement — and the first answer recorded here
was too strong. Both the original claim and its correction are kept, because
the correction is the useful part.

**First: `cc` is a linker *driver*, not a linker.** It is the thing that
computes a link line and then invokes `ld`/`ld.lld`/`gold`. So this row is not
"C linker versus Rust linker" — both routes end in a linker, quite possibly
the same one. The real question is **who computes the link line**: a C
compiler that already knows the platform, or Gust.

What `cc` supplies for free: crt object locations
(`crt1.o`/`crti.o`/`crtbegin.o`/`crtend.o`/`crtn.o`), library search paths,
the `--dynamic-linker` path, `libgcc`/`compiler-rt`, and PIE/relro/multilib
defaults — all varying by distro and architecture. That is real accumulated
knowledge, maintained by someone else, present on every machine.

**`cc` is already only a default.** The worker reads
`env::var_os("CC").unwrap_or_else(|| OsString::from("cc"))` and then invokes
it generically. The driver is a variable and `additional_linker_args` exists.

### What was measured, and what it actually shows

An earlier draft asserted that "once the runtime is a Rust staticlib the whole
link is a Rust link, and Rust already solves per-target crt and libc
discovery." **That is false on `*-linux-gnu`.** Measured by poisoning `cc`,
`gcc`, `clang`, `c++`, `g++`, `ld` and `cc1` with scripts that exit 99:

| configuration | `cc` invoked? | result |
| --- | --- | --- |
| `rustc t.rs` (gnu, default) | **yes** | poison fires |
| `rustc --target ...-musl` (default flavor) | **yes** | poison fires — self-contained crt, still driven by `cc` |
| `rustc -C linker=rust-lld -C linker-flavor=ld.lld` (gnu) | no | **fails**: `unable to find library -lc -lm -ldl -lpthread -lrt -lutil -lgcc_s` |
| `rustc --target ...-musl -C linker=rust-lld -C linker-flavor=ld.lld` | no | **works** — static-pie executable, exit 7 |

Two things follow that the earlier draft got wrong:

1. **rustc uses `cc` as its linker driver on Linux by default, including for
   the musl self-contained target.** Choosing "link with rustc" removes
   nothing on its own.
2. **On the gnu target there is no stock C-free link.** rustc emits a
   driver-style line with bare `-lc` and no search paths, because it expects
   `cc` to supply them. Making that work means hardcoding
   `/usr/lib/x86_64-linux-gnu` and friends — reimplementing, distro by
   distro, exactly the knowledge this row says not to reimplement. The
   original `rust-lld` experiment in this document did precisely that by
   hand-passing crt paths and `--dynamic-linker`, which is why it looked
   easier than it is. Note also that the gnu link wants **`-lgcc_s`**, a GCC
   runtime library, so "no C compiler" on gnu is a narrower claim than it sounds.

**The C-free link that actually works is musl + `-C linker-flavor=ld.lld`.**
So the cost is not "swap a default" but "adopt musl and static linking as the
configuration the gate is proved against."

### The decision

**`cc` stops being *required*. It does not stop being *supported*.**

- The exit gate is proved by a CI job that links with no C compiler present,
  on the musl target with `rust-lld` (D8's falsifier job is where this lives).
- `$CC` remains honoured indefinitely. Distro packagers, gnu-target users and
  anyone cross-compiling will want it, it costs one line to keep, and removing
  it buys nothing the gate asks for.

Writing it the other way round — forbidding `cc` — would be asserting an
endpoint rather than measuring one, and would regress the gnu target to no
purpose. The gate says a clean machine can build Gust without invoking a C
compiler. It does not say no machine may.

## D9a — is musl-static acceptable for the gate artifact? · **DECIDED: yes, as the proving configuration — not as the only supported target**

Previously deferred to the operator. Decided here because it is build and
packaging policy rather than an open language decision, and because it blocks
three other rows. Flagged for override rather than left open.

### The distinction that resolves it

The exit gate is about **building and testing Gust**. It says a clean machine
can do that without invoking a C compiler. It says nothing about what target
a *user's* program must be linked for. Those are two different artifacts and
the row conflated them.

So this takes the same shape as D9: **musl-static is the configuration the
gate is proved against; gnu-dynamic via `$CC` stays supported indefinitely.**
Nobody is required to ship musl binaries; CI is required to demonstrate the
C-free build once.

### Evidence

musl provides every symbol the runtime needs, checked against
`x86_64-unknown-linux-musl/lib/self-contained/libc.a` — including
`pthread_setaffinity_np`, a GNU extension `fiber.c:289` uses under
`#if defined(__linux__)`, which was the most likely symbol-level blocker:

```
pthread_setaffinity_np  present      mmap      present
pthread_create/join/self  present    sysconf   present
pthread_mutex_lock      present      fopen/fread present
```

### Caveats, recorded rather than waved past

- **`dlopen` is a non-functional stub in static musl.** It links and always
  fails. Any test needing runtime loading must run on the gnu target, and the
  D8 job should not be read as covering it.
- **musl's `mallocng` is slower than glibc's under thread contention.** The
  arena mitigates this — most allocation is bump-pointer — but the fiber
  benchmark should be run on musl **before** the gate job is treated as
  performance-representative. This is a measurement owed, not an assumption.
- Static linking has the usual binary-size and NSS consequences. For a
  compiler and its test binaries these are acceptable; for a general
  distribution policy they are not this row's call.

### Consequence for D3

A "not musl" answer would have reopened `swapcontext`. This answer keeps D3
closed, which is the better outcome independently: `swapcontext` issues a
`sigprocmask` syscall per switch against a register-only save, so it was the
weaker implementation even where it was available. Nothing about D3 now
depends on an unmade decision.

## D10 — what counts as an "optional foreign-runtime component"? · **DECIDED: an operational test, not a list**

Previously deferred to the operator. Decided here for the same reason as
D9a, and flagged for override.

### The reframe

The exception exists so that a user who wants to FFI into SQLite or OpenSSL
is not told Gust must reimplement the world first. That is legitimate and the
exception should survive. But read correctly it is about **what a user's
program chooses to link** — not about what **Gust itself requires**. Under
that reading it plainly covers SQLite, and plainly cannot reach the runtime
or the scheduler.

### The definition

A foreign-runtime component is **optional** if and only if all three hold:

1. **Absence is invisible to everything that did not ask for it.** A
   hello-world *and the full Gust test suite* build, link and run with the
   component absent from the machine.
2. **It is reachable only through a user-written `extern` declaration.**
   Never emitted by codegen, never referenced from the program entry point,
   never present in the default link line.
3. **Its absence is an error only for programs that opted in**, and that
   error names the component.

### The falsifier

This is deliberately written as a test rather than a list, so that it is
**measured by D8's no-C-compiler job** rather than argued at closure time.
That job builds and runs the full suite with no optional components present.
Anything that turns out to be needed was not optional, and the job says so by
failing.

A list would have to be maintained, and a stale list is exactly the failure
mode Phase 24 closed on: accurate about the register, incomplete about the
tree.

### What it already excludes

- **The runtime** (D2) — mandatory; every binary links it. Fails test 1.
- **The fiber scheduler** (D3) — the most tempting single candidate, and
  excluded by test 2 rather than test 1: `compiler/codegen.gst:3810` emits
  `gust_scheduler_spawn(8388608, gust_user_main, NULL)` into the program
  entry point, so it is not reached through any user `extern`.

Leaving this undefined was the real risk. The exception is wide enough,
unqualified, for someone at closure time to call the C runtime a foreign
component and pass the gate with the C still in place — which is the shape of
defect Phase 24's narrowed closure sentence exists to prevent.

# What the decisions leave open

D1-D10 are decided. Working through their consequences surfaces questions
none of them answers. Recorded here so they are found now rather than at the
gate, which is the failure Phase 24 spent five patches on.

## Blocking — decide before the work starts

**O1 — deleting `approved_scalar_imports.c` breaks 26 files.** D2 says delete
it rather than rewrite it, on the grounds that it is 15 lines of fixtures.
That is true and the conclusion is still wrong: **26 files reference
`tiny_host_add_i32` / `tiny_host_add_one_i32` / `tiny_host_is_positive_i32`**,
including `phase13_runtime_*_source.gst` and `mir_runtime_import_smoke_test_entry.gst`.
They are the corpus for the FFI and runtime-import tests — the very machinery
D2 relies on to move the other seven files. So the decision is not *delete*
but **rehome**: into a Gust definition exporting those symbols via
`extern_symbol_name`, or a Rust test shim. Deciding which, and doing it
first, is a prerequisite for D2 rather than a tidy-up after it.

**O2 — D3 and D6 disagree about how many assembly blocks exist.** The eight
blocks are structured `#if __x86_64__ { #if __APPLE__ / #else } #elif
__aarch64__ { #if __APPLE__ / #else }`. So **four are macOS-only and four are
aarch64**, and under D6 — name exactly what CI builds, which is Linux
x86_64 — only **two blocks are actually built**. D3's port is therefore 2
blocks or 8 depending on a question D6 raises and does not answer: are the
unbuilt platform branches **deleted** or **kept unbuilt**? D6 says a seed
must not imply portability it has no evidence for; it does not say the code
must go. Answer this before D3 is scheduled, because it changes the size of
the work by 4x.

**O3 — who owns the freestanding subset?** D2's first obligation is defining
the Gust subset the runtime must be written in. That is a **language-surface
definition**, not lane work, and may belong in the VISION §0.15 OD register
rather than here. Until it has an owner it will be written implicitly by
whoever ports `scratch.c` first, which is the worst outcome.

## Before the gate can close

**O4 — when does D8's job stop being allowed to fail?** A job standing red
indefinitely is decoration, not a falsifier. It needs a promotion criterion:
what makes it required, and what happens to the phase if it is still red at
that point.

**O5 — is the `$CC`/gnu path tested, or only supported?** D9 keeps `cc`
supported indefinitely and D9a makes musl the proving configuration.
Supported-but-untested rots. Either CI carries both configurations, at real
cost, or "supported" is downgraded to "not deliberately broken" and said so.

**O6 — what target do user builds default to?** Follows from D9a and is
user-visible. `gust build foo.gst` on a machine with both toolchains present
resolves to musl or gnu, and the answer has different libc behaviour.

**O7 — what exactly does D4 compare, and how is path nondeterminism
handled?** "Emitted objects" is not yet an artifact list, and objects embed
absolute paths and debug info. A `--remap-path-prefix` equivalent is almost
certainly needed. This is separate from, and in addition to, the unverified
Cranelift determinism prerequisite D4 already records.

## Release mechanics — all fall out of D1 and D7

**O8 — what *is* a release?** D1 bootstraps from the previous one and D7
requires publishing a seed digest and a fixed-point proof. Neither says what
a release is: a tag, an artifact, hosted where, obtained how — including by
a build with no network, which an auditable chain arguably requires.

**O9 — is there a bootstrap floor?** Bootstrap-from-previous-release means
either every intermediate release must exist forever, or a floor is declared
and releases below it are unsupported. Rust and Go both hit this; it is
cheaper to decide now than to discover.

**O10 — what attests a release?** D7's "verified rather than trusted" rests
on the fixed-point proof, but a published digest still needs provenance, and
the checked-in bridge binary of D1's option B needs it more.

## Measurements owed — not decisions

- Cranelift object determinism (D4's prerequisite).
- D9's poison test extended past `std` to the runtime archive, pthread and
  the host object.
- The fiber benchmark on musl before D9a's job is called performance-
  representative.

## Sequence implied by the above

1. Enumerate what actually requires a C toolchain, measured (pre-work, stated above).
2. Stand up the no-C-compiler CI job as the standing falsifier (D8).
3. Verify Cranelift object determinism (D4 prerequisite).
4. Define and guard the freestanding Gust subset the runtime must be written
   in (D2's first obligation), then runtime to **Gust** file by file behind
   parity evidence — `scratch.c`, `strings.c`, `host_io.c` first to exercise
   the subset, `arena.c` behind its no-allocate guard, Rust as the per-file
   fallback. Delete `approved_scalar_imports.c` rather than rewriting it.
   `fiber.c` last, as a `#![no_std]` Rust crate carrying the two
   `global_asm!` blocks verbatim (D3).
5. Native stage chain and the new fixed point (D4).
6. Seed cut-over (D1).
7. Delete the emitter and its entry together (D5).
8. Make `cc` optional rather than required (D9): keep `$CC` honoured, and
   prove the gate with a musl + `rust-lld` link in the D8 job. Extend the
   measured link to cover the runtime archive, pthread and the host object —
   none of which the `std`-only measurement covered.
