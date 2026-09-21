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

**Bootstrap from the previous release (option A), with a verified published
binary whose digest is committed (option B) as the bridge. Do the runtime
before the seed.**

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

**B — published native binary with a committed digest.** A prebuilt `gust`
per platform, published as a release asset, with its digest tracked in the
repository. *Narrowed by P15 — this row originally said the binary itself
was committed, which contradicted O8.*

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
| 2 | **B**, *if the fixed point proves it* | The usual objection is that a blob cannot be diffed. This repository already has the machinery that answers it: require the committed binary to rebuild itself byte-identically from source. That makes the seed **reproducible**, which is most but not all of what auditability buys — see D7 and O11: a compromised seed reproduces itself too. Cost: one artifact per platform. Narrowed by P15: the binary is published and its digest committed, not the binary itself. |
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
| `approved_scalar_imports.c` | 15 | nothing | **rehome, not delete** — 26 files depend on its three symbols; see O1 |
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

**Superseded in two places by the O-series.** This row said to *delete*
`approved_scalar_imports.c`; O1 shows 26 files depend on its symbols and it
must be rehomed into D3's Rust crate instead, before the port rather than
after. And this row treated defining the freestanding subset as an obligation
without an owner; O3 assigns it and makes it patch 1.

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

**Amended by O1 and O2.** The *crate* is created early, because O1 rehomes
the `tiny_host_*` fixtures into it before the runtime port begins; only
`fiber.c` itself moves last. And all **eight** blocks port, not the two CI
builds: O2 finds that D6 binds the seed rather than the runtime, and that
deleting by architecture would delete Apple Silicon, since macOS is aarch64.

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
portability it has no evidence for. **This binds the seed, not the
runtime** — see O2, where reading it as a licence to delete runtime platform
branches was the error. A seed supporting one platform while the
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

**Corrected after review (PR #444, P2).** That sentence claimed more than the
fixed point delivers, and the argument that refutes it is one **this same
document already makes in D2**: the fixed point cannot detect a *consistent*
miscompile. That is the Thompson property. Applied to D2 it weakened the
bootstrap-circle objection; applied here it undercuts the justification for
option B, and the document used it in one place and not the other.

Rebuilding a seed byte-identically from source proves **a fixed point, not
that the binary implements the source you read**. A compromised seed that
reproduces itself passes this test exactly as a clean one does. So the fixed
point is necessary and it is not sufficient, and "verified rather than
trusted" overstates it.

What (a) and (b) actually buy, stated honestly: **reproducibility** — that the
artifact corresponds to *some* fixed point of the published source, and that
anyone can confirm they obtained the same artifact everyone else did. That is
worth having and it is not provenance.

**Closing the gap needs an independent mechanism, and this document does not
have one yet.** The candidate is **diverse double compilation**: build the
compiler with an independent implementation — the previous release built on a
different toolchain, or a second compiler — and require the two to converge on
the same artifact. A seed compromise survives self-reproduction; it does not
survive being reproduced by something that never contained it.

This is now an open row, deliberately not resolved here:

> **O11 — what independent provenance mechanism closes the Thompson gap?**
> Diverse double compilation is the obvious candidate and it has a real cost:
> it needs a second, independently obtained compiler in the release pipeline.
> Until it is decided, D7 claims **reproducibility**, not verification, and
> O10's layering is correspondingly weaker: the fixed point still beats a
> signature, but neither establishes that the binary implements the source.

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

# What the decisions left open — resolved

D1-D10 are decided. Working through their consequences surfaced ten further
questions, all resolved here on 2026-09-19. None was left to the operator;
each says what it rests on, so a wrong one can be found and reversed.

## O1 — the `tiny_host_*` fixtures · **RESOLVED: rehome into D3's Rust crate, symbol names unchanged, guards updated in the same patch**

D2 said *delete* `approved_scalar_imports.c` as 15 lines of fixtures. It is
15 lines of fixtures and the conclusion was still wrong. **26 files depend on
those three symbols** — the `phase13_runtime_*` sources, four
`mir_*_smoke_test_entry.gst`, `phase17_runtime_import.py`,
`phase17_runtime_symbol_version.py`, `phase20_stdlib_runtime_differential.py`,
`phase21_full_compiler_native_qualification.py`, and
`cranelift_feature_registry.json` with its schema. They are the approved-
runtime-import corpus, which is the machinery D2 relies on to move the other
seven files.

**They must not be rewritten in Gust.** The point of the fixtures is that the
callee is *foreign*; a Gust implementation would test Gust calling Gust and
the contract under test would evaporate. This is the trap in "everything goes
to Gust" and it is worth stating because D2 makes it sound obvious.

**They go into the `#![no_std]` Rust crate D3 creates.** That keeps them
genuinely foreign, uses a crate that must exist anyway, and the FFI surface
they then exercise — Gust calling Rust — is exactly the surface that survives
D2 and D3. Symbol names stay byte-identical, so no registry *value* changes.

**Consequence for sequencing, which D3 did not anticipate:** D3 sequences
`fiber.c` last. The crate it creates is needed *first*. So the crate is
created early with the fixtures in it, and `fiber.c` moves into it last. The
crate's creation and `fiber.c`'s port are separate patches.

**This is not a free move.** Two guards assert the C file by path or product:
`scripts/cranelift_registry.py:2538` tests
`source["source_path"] == "src/runtime/approved_scalar_imports.c"`, and
`scripts/phase21_full_compiler_native_qualification.py:92` expects
`approved_scalar_imports.o` in the object set.
`scripts/phase20_stdlib_runtime_differential.py:57` carries
`runtime_component:approved_scalar_imports`, and the Phase 17 package and
symbol-version guards carry `three_approved_scalar_imports` boundary sets.
Those updates are **part of the rehoming patch**, with a successor record,
not a follow-up. `cranelift_feature_registry.json` is edited in place and
never reserialized.

## O2 — how many assembly blocks · **RESOLVED: port all eight; D6 binds the seed, not the runtime**

The conflict dissolves once the two artifacts are separated. **D6 requires
the *seed* to name the platforms it can bootstrap. It does not require the
*runtime* to drop platforms it already supports.** Those are different
artifacts with different obligations, and reading D6 as a licence to delete
runtime code was the error.

The arithmetic also does not support deleting by architecture.
The blocks are `#if __x86_64__ { #if __APPLE__ / #else } #elif __aarch64__
{ #if __APPLE__ / #else }`, so the four quadrants are macOS-x86_64,
Linux-x86_64, **macOS-aarch64** and Linux-aarch64. Modern macOS *is*
aarch64, so "delete aarch64, keep darwin" is incoherent — and
`compiler/mir_target_authority.gst` names `"darwin"` as a live target, so
deleting its support would contradict a live authority rather than tidy up.

So: **port all eight blocks, preserving all four quadrants.** The marginal
cost over porting two is close to zero, because this is D3's copy-paste —
the same assembly text under the same `cfg` structure, `#if` becoming
`#[cfg]`. Add a guard asserting the ported crate carries the same four
platform quadrants as `fiber.c` did, so the copy-paste is provably lossless.

Record explicitly that **three of the four quadrants remain unbuilt**. That
is a pre-existing condition, and the port must neither silently worsen it nor
silently claim to have fixed it. D6's obligation is discharged by the seed
naming Linux x86_64, not by the runtime shedding code.

## O3 — who owns the freestanding subset · **RESOLVED: lane-owned spec plus guard, delivered as patch 1; escalates to the OD register only if it needs new language surface**

The subset is **derivable, not designed**: it is exactly what remains once
runtime code may not use the `str`, `Vector`, `HashMap` and arena it
implements. A derivable constraint is lane work. VISION §0.15's OD register
is for genuinely open language questions — OD-3 shared ownership, OD-9 model
fluency — and putting a derivable constraint there would dilute it.

So the rule is: **derivable constraint → lane; new language surface → OD.**
If defining the subset turns out to need a new spelling — a `#[freestanding]`
attribute, a module-level mode — *that* is an OD and escalates. Writing a
document that says "do not call `std.Clone` here" is not.

It is delivered as **the first patch of the runtime work**, before any file
moves, and the deliverable is a spec section **and a guard**. The guard is
what makes it real: a subset that exists only as prose will be violated by
the first port and nobody will notice until the compiler recurses. The
failure mode this prevents — the subset written implicitly by whoever ports
`scratch.c` first — is the reason it is sequenced first rather than
alongside.

## O4 — when D8's job stops being allowed to fail · **RESOLVED: expected-red with a named reason; required the moment the last C source leaves the tree**

There is no `continue-on-error` precedent anywhere in the repository's 153
workflows, so a job standing red would be anomalous and would be read as
breakage. It therefore needs a stated contract rather than an exemption.

The job is **non-required and expected-red from the start, and it carries
its expected-failure reason as data**: the list of C inputs still required.
It must fail for *that* reason. **Failing for a different reason is a
regression and is reported as one** — that is the inversion discipline
applied to a CI job, and it is what makes an expected-red job a measurement
rather than decoration.

Its promotion criterion is **mechanical, not a date**: it becomes required
at the moment its expected-failure list empties, which is the moment the last
C source leaves the tree. So the job cannot be "allowed to fail" indefinitely
by inattention — the list is the schedule, and it shrinks patch by patch.

## O5 — is the `$CC`/gnu path tested · **RESOLVED: one gnu smoke job, and say plainly that the full suite is musl-only**

Doubling a 153-workflow matrix is not a real option and pretending otherwise
would be how "supported" quietly becomes "untested".

**Supported means: builds, links, and passes a defined smoke subset on the
gnu target.** One job, not the matrix. Everything beyond that subset is
proved on musl only, and the documentation says so in those words rather
than implying parity. A user on gnu gets a working compiler and an honest
statement of what was verified.

This is the same move as D9 and D9a — a narrower claim that is true, instead
of a broad one that rots.

## O6 — default target for user builds · **RESOLVED: the host's native target; musl is opt-in**

`gust build foo.gst` on a glibc host produces a glibc binary. Defaulting to
musl would hand users a static binary with a `dlopen` that always fails and
different name-resolution behaviour, as a side effect of a decision about how
*Gust's own CI* proves a gate. That is a bad trade and users did not ask for
it.

musl is reachable by explicit `--target`. This follows directly from D9a:
musl is the **proving configuration**, not the supported default, and the
distinction is worth nothing if the user-facing default quietly follows the
CI configuration.

## O7 — what D4 compares, and path nondeterminism · **RESOLVED: the compiler's own object set, paths remapped, debug info included**

Three parts, because "compare emitted objects" named none of them.

**The artifact set** is the objects the compiler emits for `compiler/*.gst`
— the compiler compiling itself. Not the runtime objects, which are built by
a different toolchain under D2 and D3 and whose reproducibility is that
toolchain's problem, and not linked executables, which is D4's original
point.

**Paths are remapped at build time**, not stripped afterwards. Absolute
paths enter objects through debug info and through any embedded source
location, and a fixed point that only holds inside one checkout directory is
not the property D7 promises a third party.

**Debug info is included in the comparison, not stripped.** Stripping would
make the comparison pass more easily and would hide exactly the class of
nondeterminism most likely to be present. If it turns out determinism holds
only after stripping, that is a **narrower fixed point** and must be recorded
as one — with the stripped sections named — rather than quietly adopted. The
difference between "the compiler reproduces itself" and "the compiler
reproduces itself except for the parts we did not look at" is the whole
value of the proof.

This is separate from, and in addition to, D4's already-recorded prerequisite
that Cranelift's object output be deterministic at all.

## O8 — what a release *is* · **RESOLVED: an annotated tag, an artifact set with a digest manifest, and no network on the critical path**

A release is:

1. An **annotated git tag**.
2. An **artifact set** attached to it: the per-platform bridge binaries of
   D1 option B, the fixed-point proof log, and a **manifest** listing every
   artifact with its digest.
3. The manifest, and only the manifest, is **also committed to the
   repository as tracked text**. Binaries live as release assets; the text
   that describes them lives in git, where it is diffable and where D7's
   "tracked text or a proved artifact" condition can see it.

**The network is never on the critical path.** The build accepts a local
path to the seed (`GUST_BOOTSTRAP_SEED=/path/to/artifact`) and verifies it
against the tracked manifest digest. Fetching is a convenience for the common
case, not a requirement. An auditable chain that cannot be built offline is
not auditable by anyone who does not trust the host, which is most of the
people the property is for.

## O9 — is there a bootstrap floor · **RESOLVED: N-1 only, with the checked-in bridge as the documented escape**

**Release N builds from release N-1 and nothing older is promised.** Every
intermediate tag continues to exist — they are tags and assets, which cost
nothing to keep — but the supported, tested path is one step.

Promising more would mean testing more, and a chain nobody exercises is a
chain that is already broken. Rust and Go both arrived here; there is no
reason to rediscover it.

**The escape is D1's option B, and this is what it is for.** If the chain is
broken — an intermediate release is unreproducible, or someone is
bootstrapping from nothing — the checked-in verified bridge binary re-enters
the chain in one step. B being "the bridge" is not a transitional note; it is
the permanent answer to the floor problem.

## O10 — what attests a release · **RESOLVED: two layers, and the reproducible one is the one that counts**

**Layer 1, the attestation that matters: the fixed-point proof.** It says
the artifact is *a* fixed point of the published source, and anyone can
regenerate it. Narrowed by O11: this is **reproducibility**, not proof that
the binary implements the source — a compromised seed reproduces itself too.
It is still the stronger of the two layers.

**Layer 2, provenance: a signed manifest.** Signing the digest manifest —
via whatever the project already uses for tags, or GitHub artifact
attestations — says *who published it*. This is worth having, and it is
strictly the weaker claim.

Stated plainly so the two are not confused: **a signature on a blob nobody
can reproduce is trust, not verification.** If the two layers ever conflict,
the fixed point wins and the release is withdrawn. Layer 2 exists to detect
substitution, not to substitute for layer 1.


# Round three — what O1-O10 left open

Resolved 2026-09-19, same session. One of these is a **contradiction between
two decided rows**, which is the reason to keep doing these rounds.

## P15 — D1 and O8 contradict each other · **RESOLVED: O8 wins; D1's option B narrows to "published binary, committed digest"**

Taking this first because it is a conflict rather than a gap.

- **D1 option B:** "a prebuilt `gust` per platform, **committed**."
- **O8:** "Binaries live as release assets; the manifest, **and only the
  manifest**, is also committed."

Both cannot hold. **O8 is right.** Committing per-platform binaries writes
blobs into git history permanently, growing every clone forever for a file
almost nobody needs — and opacity is precisely what D1's own ranking held
against option C when it placed C below B.

The *property* option B buys is a bridge that does not require a previous
release to exist. That property survives intact: **the bridge is a release
asset whose digest is committed**, alongside the fixed-point proof. Anyone
can obtain a copy by any route and verify it against tracked text. Combined
with O8's `GUST_BOOTSTRAP_SEED=/path`, the offline story holds too.

D1's option B wording is hereby narrowed from *committed binary* to
**published binary with committed digest**. The ranking is unaffected — B
stays second, and stays the bridge for O9's floor.

Honest limitation, stated rather than papered over: with **neither** network
**nor** any release asset, there is nothing to bootstrap from. That is also
true of Rust and Go, and it is the cost of retiring a checked-in seed.

## P1 — the crate adds a second archive, and #436 is open · **RESOLVED: re-measure, record on #436, do not close it on a stale scan**

There is exactly **one** `.a` in the build today, `build/gust-runtime-package.a`
(`Makefile:18`). O1's crate makes two.

#436 is open precisely because `build_system_produces`'s `\.a\b` fallback
misclassifies — it put **105 of 117** justfile inputs in `rust-archive`
against 1 in the rest of the tree. Adding a second archive is a new input to
that open issue.

So: the rehoming patch **re-runs the C-toolchain provenance scan and records
the delta on #436**. And #436 must not be closed on the strength of a scan
taken before the second archive existed — that is the shape of defect #423
was reverted for, a guard green over a population it classified by accident.

## P2 — `phase21`'s object set meets an archive · **RESOLVED: teach the guard archives; do not delete the row**

`scripts/phase21_full_compiler_native_qualification.py:92` names a set of
runtime **objects**, including `approved_scalar_imports.o`. A Rust staticlib
is an **archive** containing objects, so the population changes shape, not
just membership.

Two ways to make it green, and only one is honest. Extracting the crate's
objects so the existing guard still sees `.o` files defeats the point of the
crate and adds a build step whose only purpose is to satisfy a guard. So:
**teach the guard to accept an archive as a member**, and re-derive its
population rather than deleting the row that no longer matches. Deleting the
row would make it pass while measuring less, which is #423 again.

## P3 — does a `#![no_std]` staticlib actually work · **RESOLVED: yes, measured**

> **SUPERSEDED by P17 for the SCHEDULER, still true as written.** P3 asked
> whether a `no_std` staticlib builds and exports its symbols. It does, and
> that answer is unchanged. What P3 did not ask is whether `no_std` can hold
> the scheduler, and Patch 25.6 measured that it cannot. See P17.


Recorded so the first patch does not rediscover it. A `staticlib` crate with
`#![no_std]`, `panic = "abort"`, a trivial `#[panic_handler]`, three
`#[no_mangle] extern "C"` fixtures and a `global_asm!` block builds clean and
exports all four symbols:

```
nm -g target/release/libgustrt.a
  T gust_context_switch
  T tiny_host_add_i32
  T tiny_host_add_one_i32
  T tiny_host_is_positive_i32
```

`global_asm!` needs `options(att_syntax)` for the AT&T-syntax bodies
`fiber.c` already uses, which keeps the copy-paste literal.

## P4 — the macOS underscore variants · **RESOLVED: keep both spellings explicitly, as the C did**

`#[no_mangle]` applies the platform symbol prefix for *functions*, but
`global_asm!` is raw text and gets no such treatment. So the
`_gust_context_switch` / `gust_context_switch` pair must stay explicit under
`#[cfg(target_vendor = "apple")]`, exactly as `#if defined(__APPLE__)`
carried it. The port stays a literal copy-paste, underscores included.

## P5 — what proves the copy-paste lossless · **RESOLVED: byte comparison for the built quadrant, text comparison for the other three, and say which is which**

Three of the four platform quadrants are unbuilt (O2), so there are no bytes
to compare for them. The guard therefore has two halves:

- **Built quadrant (Linux x86_64): compare emitted bytes** for
  `gust_context_switch` and `gust_fiber_entry_wrapper`, old against new.
- **Unbuilt quadrants: compare assembly text**, extracted per `#[cfg]` arm
  from the crate and per `#if` arm from `fiber.c` at its last commit,
  normalised for whitespace only.

The text half is **weaker and is labelled as weaker**. It is accepted because
the alternative is no evidence at all for three quadrants, not because text
equality proves behaviour. If an aarch64 runner ever appears, that half is
promoted to a byte comparison and the guard says so.

## P6 — how the freestanding subset is enforced · **RESOLVED: relocations, not grep — so O3's escalation rule does not fire**

O3 said "spec plus guard" without saying what the guard inspects, and the
obvious answer is wrong. A guard that greps runtime `.gst` files for
`std.Clone` is **a name test standing in for a behaviour test**: it passes
for anything spelled differently, aliased, or reached one call deep.

The strong enforcement needs no new language surface: **inspect the emitted
object's relocations.** A runtime object carrying a relocation against
`std_*`, `os_ArenaAlloc` or any other runtime export violated the subset,
however it was spelled. That is the same technique D2's third obligation
already specifies for `os_ArenaAlloc`, so the two guards are one mechanism
applied twice.

This matters for O3's own rule. A `#[freestanding]` module attribute *would*
be new language surface and *would* escalate to the OD register — and it is
the stronger answer, because it fails at compile time with a good message
rather than at guard time with a relocation name. It is recorded here as the
Phase 26 successor, and it is **not needed now**, so O3's rule does not fire
and the subset stays lane work.

## P7 — where D8's expected-failure list lives · **RESOLVED: a standalone tracked JSON, read by the job at runtime**

Not in `scripts/cranelift_feature_registry.json`. A top-level key there costs
three coordinated files — the registry, `TOP_FIELDS` in
`cranelift_registry.py`, and the schema's `required` — and this is not a
Cranelift feature.

A standalone tracked JSON, carrying the repo's successor-chain convention so
each patch that shortens the list says what it removed and why. **The job
reads it at runtime** rather than restating it, so the list and the job
cannot drift apart — a job that hardcodes what it expects to fail will one
day expect something the list no longer says.

## P8 — the promotion transition · **RESOLVED: a patch, never automatic**

If promotion were automatic, the day the list empties an unrelated failure
becomes a blocking required check with nobody expecting it — a green-to-red
transition caused by a *success* elsewhere, which is the worst kind to debug.

So the job reports **"list empty, ready for promotion"** and stays
non-required. A patch flips it. That patch is the phase's closure patch, and
tying them together is a feature: the gate becomes required exactly when
someone writes down that it should be.

## P9 — what is in the gnu smoke subset · **RESOLVED: named in the workflow, not computed**

Build the compiler, run the bootstrap fixed point, and run one exec test per
backend route. Small, fixed, and **enumerated literally in the workflow
file**.

A computed subset — "everything tagged smoke", "the fast half" — drifts
toward nothing as tags rot, and nobody notices because the job stays green
while covering less. O5 bought one job; this is what keeps it worth having.

## P10 — host-native default on a machine with no C compiler · **RESOLVED: probe, then error naming musl — never switch silently**

This falls straight out of D9 and O6 together and neither noticed it. O6
defaults user builds to the host's native target; D9 establishes that on a
gnu host the native link needs a C compiler. **On a gnu host with no C
compiler, the default therefore fails.**

The driver probes for a usable link driver. If none is found it **errors,
naming `--target x86_64-unknown-linux-musl` as the fix.** It does *not*
silently fall back to musl: that would hand the user a static binary with a
non-functional `dlopen` and different name resolution as a side effect of
their machine's package list, which is exactly the surprise O6 refused. An
error the user can act on beats a binary they did not ask for.

## P11 — Cranelift emits no debug info today · **RESOLVED: restate O7 as a standing obligation, and record that it is vacuous now**

Measured: there is no `debug_info`, `DWARF` or `debuginfo` handling in
`compiler/experiments/cranelift/src/main.rs`. So O7's "debug info is included
in the comparison, not stripped" is **currently vacuous** — there is nothing
to include.

Restated so it does not need remembering: **the comparison covers every
section the compiler emits.** The day debug info starts being emitted it is
in scope automatically. And recorded here explicitly so nobody reads today's
passing comparison as evidence about debug-info determinism, which it is not.

## P12 — remap to what · **RESOLVED: one pinned canonical prefix, constant in the build**

`/gust`, chosen once and recorded, so two checkouts in different directories
emit identical objects. It must be a **build constant, never derived from
`cwd`** — a remap computed from the working directory reproduces the very
nondeterminism it exists to remove, while looking like it fixed it.

## P13 — who cuts a release · **RESOLVED: the normal gate, no admin path**

A release is a tag on merged `main`, cut by a patch that lands through the
same ruleset as everything else: mergeable, zero unresolved review threads,
required checks green. No `--admin`, no exception for release patches. A
bootstrap chain whose releases bypass the review gate is not the auditable
chain D7 describes.

D1's release 0 is minted from today's `gust_v4.c` **before** D5 deletes the
emitter — already satisfied by the sequence, which puts release mechanics at
step 9 and emitter deletion at step 11, and noted here so a future reorder
does not quietly break it.

## P17 — can the runtime crate stay `#![no_std]` · **RESOLVED: no, once the scheduler moves — and Phase 25's gate is *no C compiler*, not *no libc***

P3 established that a `no_std` staticlib builds and exports its symbols, and
that remains true. It was answered against a crate holding three scalar
fixtures and a `global_asm!` block. `fiber.c`'s scheduler is a different
question and Patch 25.6 had to answer it.

**`pthread_mutex_t` decides it.** Forty-four of `fiber.c`'s calls are mutex
operations, and that type is OPAQUE — its size and alignment belong to the
libc, not to any standard. Measured here: 40 bytes, align 8, glibc x86_64.
NOT measured for musl or macOS, because no second libc is installed on this
machine; the type is opaque precisely so it may differ.

A `no_std` port must therefore hand-declare it as a guessed byte array per
platform. Guess low and the mutex writes over adjacent memory; guess high
and it merely wastes space. **Both are silent.** This patch is committed to
all four platform quadrants (O2, D6) and three cannot be built here, so
three of the four guesses would be unverifiable in principle — a defect that
appears only where nobody builds is the worst shape available.

`cpu_set_t` is the same trap a second time, for thread affinity. That one
was avoidable by going to the kernel's `sched_setaffinity` ABI — a byte size
and a bitmask, both stable — instead of the libc struct. The mutex has no
such escape.

**What `std` costs the phase: nothing it is buying.** The gate is a build
and test with no C COMPILER. Linking libc requires no `cc`. `std` supplies
`Mutex` and `thread` with no layout to guess, and `panic = "abort"` is kept,
so the abort behaviour 25.4's fixtures relied on is unchanged.

The alternative considered and rejected: pinning the toolchain to nightly
for `#[thread_local]`. That is a far larger commitment than one attribute
justifies, and it would bind the bootstrap chain — the thing D7 wants
auditable — to an unstable compiler.

**What this does not rescue.** `gust_loop_ticks` was a thread-local *int*,
and `std` does not help there either: stable Rust cannot export a C-visible
`__thread` data symbol at all. That counter moved behind a call, at a
measured cost — see the roadmap's benchmark section, and note the cost falls
on the generated-C route that 25.10 deletes.

## Measurements owed before the first patch

Not decisions — three facts the decided rows assume and nobody has checked.
This list was dropped by an editing error when the O-series replaced the
section that held it, and is restored here.

1. **Cranelift object determinism** (D4's prerequisite). If it does not hold,
   the fixed point as specified does not exist and that is a prerequisite
   patch, not a footnote.
2. **D9's poison test extended past `std`** to the runtime archive, pthread
   and the host object. What was measured is a mechanism proof on a
   `std`-only binary, not the Gust link.
3. **The fiber benchmark on musl** (D9a). musl's `mallocng` is slower than
   glibc's under contention; until this is run, the D8 job is a correctness
   falsifier and not a performance-representative one.

## Still required before Phase 25 can start

Beyond the measurements above, and beyond this document merging:

- **A patch breakdown.** There is no `Patch 25.x` sequence anywhere in the
  repository. This document decides *what* and *in what order*; it is not a
  task list and `TASK.md` still belongs to Phase 24, whose closure patch
  24.18 is DONE. Writing that breakdown is the first Phase 25 act.
- **#433.** Two of the five Makefile bootstrap callers still reach the
  emitter through the retired `--backend mir-to-c` spelling, and both run on
  **seed-derived** binaries, so the seed cannot reconverge. Phase 25's whole
  subject is the seed; this is the one open issue that blocks the phase
  rather than a patch within it.
- **#431 and #436, which block specific patches rather than the phase.** P2
  must teach `phase21_full_compiler_native_qualification` about archives,
  and #431 reports that guard's baseline falsified on `main`; P1's second
  archive is a new input to #436's `\.a\b` misclassification.

## Sequence implied by the above

Reordered by O1 and O3, which moved work earlier than D2 and D3 assumed.

1. Enumerate what actually requires a C toolchain, measured (pre-work, stated above).
2. Stand up the no-C-compiler CI job as the standing falsifier (D8), carrying
   its expected-failure list as data and required to fail for that reason
   only (O4). Add the single gnu smoke job at the same time (O5).
3. Verify Cranelift object determinism, and fix the artifact set, path
   remapping and debug-info policy while doing it (D4 prerequisite, O7).
4. **Define and guard the freestanding Gust subset** — spec section *and*
   guard, before any file moves (D2's first obligation, O3).
5. **Create the `#![no_std]` Rust crate and rehome the `tiny_host_*`
   fixtures into it**, updating `cranelift_registry.py:2538`,
   `phase21_full_compiler_native_qualification.py:92`,
   `phase20_stdlib_runtime_differential.py:57` and the Phase 17 boundary sets
   in the same patch (O1). This is now *before* the runtime port, not after.
6. Runtime to **Gust** file by file behind parity evidence — `scratch.c`,
   `strings.c`, `host_io.c` first to exercise the subset, `arena.c` behind
   its no-allocate guard, Rust as the per-file fallback (D2).
7. `fiber.c` last, into the crate from step 5, porting **all eight**
   `global_asm!` blocks and preserving all four platform quadrants, with a
   guard proving the copy-paste lossless (D3, O2).
8. Native stage chain and the new fixed point (D4).
9. Release mechanics — tag, artifact set, tracked digest manifest, offline
   seed path, N-1 floor, signed manifest (O8, O9, O10). **Before** the seed
   cut-over, which has nothing to bootstrap from otherwise.
10. Seed cut-over (D1).
11. Delete the emitter and its entry together (D5).
12. Make `cc` optional rather than required (D9): keep `$CC` honoured, prove
    the gate with a musl + `rust-lld` link, and extend the measured link to
    cover the runtime archive, pthread and the host object — none of which
    the `std`-only measurement covered. The host default stays native (O6).
