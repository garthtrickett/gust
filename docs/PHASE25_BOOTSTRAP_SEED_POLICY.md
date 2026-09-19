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

## D2 — the C runtime's disposition · *lane* · **DECIDED: Rust, on sequencing grounds — not capability**

1,968 hand-written lines across eight files, linked into every binary.

**An earlier draft of this row said Gust was blocked by Phase 26.1. That was
wrong, and the measurement is recorded here so the claim is not made again.**
Gust already has bodyless `extern func f(a: int) int;` FFI, unsafe-gated at
the call site (`compiler/parser_ffi_metadata_test_entry.gst`), with aggregate
returns working (`phase13_parameter_argument_aggregate_return_source.gst`).
It has raw pointers with provenance tracking and `*p` deref
(`typechecker_raw_sandbox_provenance_expression_flow_test_entry.gst`), and
1,416 `unsafe` sites across `compiler/*.gst`. `docs/ROADMAP_TAIL.md:196` says
26.1 **completes** gated raw pointers and FFI — completes, not introduces.
"Blocked by 26.1" was a restatement of the roadmap heading, not a measurement.

What the eight files actually need, measured:

| file | lines | needs | expressible in Gust today |
| --- | --- | --- | --- |
| `approved_scalar_imports.c` | 15 | nothing | **delete, not rewrite** — `tiny_host_add_one_i32` and two siblings, test fixtures only |
| `host_io.c` | 60 | `malloc` `memcpy` `strlen` | yes, via `extern func` |
| `scratch.c` | 80 | `memset` `exit` | yes |
| `arena.c` | 122 | `malloc` `free` `memset` | yes in principle — see the self-reference below |
| `strings.c` | 130 | `memcpy` `exit` | yes; `std_str_eq`/`find`/`byte_at` are pure byte loops |
| `collections.c` | 243 | `memcpy` `memset` + C preprocessor macros for generics | yes; Gust has real generics, which is a better fit than `core_headers.h:233`'s macro |
| `file_io.c` | 599 | stdio + pthread mutex | yes, via `extern func` |
| `fiber.c` | 719 | **8 `__asm__` blocks** + pthreads | **no** — see D3 |

So only one of the eight is capability-blocked. The other seven go to Rust for
three reasons that are about **sequencing and risk**, not about what Gust can
express:

1. **Keep the bootstrap circle small while it is being re-established.**
   Phase 25's job is deleting C and proving a native fixed point. A Gust
   runtime is *inside* that circle: it would be compiled by the compiler whose
   self-reproduction is the thing under proof, so a runtime miscompile and a
   compiler miscompile become indistinguishable from the fixed point alone. A
   Rust runtime stays outside it. This is the load-bearing argument.
2. **`arena.c` is self-referential in a way the compiler is not.**
   `os_ArenaAlloc` is what codegen emits for `ctx[...]`; it is compiler-known
   by name (`compiler/codegen.gst:692`). A Gust `os_ArenaAlloc` must provably
   never allocate, and nothing in the language enforces that today.
3. **ABI layout enforcement is the one 26.1 item that genuinely bites.**
   `os_Arena` is matched by name in `compiler/codegen.gst:69-70` and its layout
   is fixed in `src/runtime/core_headers.h:53`. A Gust rewrite must reproduce
   that layout exactly, and Gust has no layout-control construct. This is
   narrower than "raw pointers and FFI are 26.1", and it is real.

**Declaring it a foreign component does not satisfy the gate.** The exit gate
excepts *optional* foreign-runtime components. This runtime is mandatory —
every binary links it — so the escape clause does not reach it. That is worth
stating because it is the tempting shortcut.

This does not foreclose Gust. C→Rust now and Rust→Gust after 26.1 compose, and
after 26.1 adds layout enforcement the three reasons above weaken to one. A
lane that wants to take `strings.c` or `scratch.c` to Gust inside Phase 25
should be allowed to argue it on parity evidence; this row is a default, not a
prohibition.

Risk: this is a real rewrite of arena and fiber semantics, not a translation.
`scripts/phase17_retained_c_runtime_parity.sh` already exists as a comparison
harness and should gate each file.

## D3 — `fiber.c` specifically · *lane* · **DECIDED: Rust with `global_asm!`**

719 lines carrying **eight blocks of inline assembly** for context switching,
plus pthread. This is the one file where the Gust answer is blocked on
capability rather than sequencing, and the block is measured: there is no
`asm` construct anywhere in `compiler/lexer.gst`, `compiler/parser.gst`,
`compiler/codegen.gst`, or the spec. Register-level context switching has no
Gust spelling at all, and 26.1 does not add one. Rust supports
`global_asm!`/`asm!` directly, so the assembly ports as assembly rather than
being reimplemented.

It is also the file most likely to be argued into the "foreign component"
bucket. It should not be: `gust_context_switch` and `gust_scheduler_*` are
exported into every binary, so D2's mandatory-not-optional finding applies
here too. Sequence it **last** of the eight, behind the files with cheaper
parity evidence.

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

## D9 — does `cc` survive as the linker driver? · *lane* · **DECIDED: no**

Asked as policy, answered by measurement.

**`cc` is already only a default.** The worker reads
`env::var_os("CC").unwrap_or_else(|| OsString::from("cc"))` and then invokes
it generically — objects, optional host object, the runtime archive, `-l`
libraries, `-o`. Nothing is welded to a C compiler; the driver is a variable
and `additional_linker_args` already exists.

**A non-C driver is already installed.** `rust-lld` ships inside the Rust
toolchain at `lib/rustlib/<target>/bin/`, and Rust is a hard dependency
already. No new tool is required.

**Verified end to end, not argued:**

```
rustc --emit=obj t.rs -o t.o          # any object; no C involved
rust-lld -flavor gnu -o prog \
    crt1.o crti.o t.o -lc crtn.o \
    --dynamic-linker /lib64/ld-linux-x86-64.so.2
./prog  ->  exit 7
```

A working dynamically linked executable with **no C compiler invoked**.

Scope of that result, stated honestly: it proves the mechanism, not the whole
Gust link. It does not yet cover the runtime archive, pthread, or the host
object, and it was run on `x86_64-unknown-linux-gnu` only. Those are the next
measurements, not assumptions to carry forward.

**What it still needs:** `crt1.o`/`crti.o`/`crtn.o` and `libc`, which come
from libc development files — *not* from a compiler. So the gate's wording,
"without invoking a C compiler", is satisfiable with libc-dev present.

**Why this is natural rather than a workaround:** D2 moves the runtime to
Rust. Once the runtime is a Rust staticlib, the whole link is a Rust link, and
Rust already solves per-target crt and libc discovery. Reimplementing that
discovery inside Gust would be duplicating a solved problem badly.

One trap worth recording: **`rustc`'s own default linker on
`x86_64-unknown-linux-gnu` is `cc`.** "Link with rustc" does not by itself
remove the C toolchain; it needs `-C linker=rust-lld`, or lld invoked
directly as above. Choosing rustc-as-driver without that flag would look like
progress and change nothing.

## D9a — is libc-dev acceptable, or must the link be self-contained? · **operator**

What remains of D9 after the measurement, and it is a much smaller question.

- **Tier 2 (measured above):** `rust-lld` + system crt and libc. No C
  compiler is invoked. Needs libc development files present.
- **Tier 3:** an `x86_64-unknown-linux-musl` target with
  `-C link-self-contained=yes`, where Rust ships musl's crt objects itself.
  No system C artifacts at all. Costs musl and static linking, with the libc
  behaviour and binary-size consequences that implies.

Tier 2 satisfies the exit gate as written. Tier 3 satisfies the stronger
claim some readers will hear in "Gust does not need C". Which one the phase
is closing on is the operator's call, and it should be made **before** the
closure sentence is drafted.

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
4. Runtime to Rust, file by file behind parity evidence; delete
   `approved_scalar_imports.c` rather than rewriting it; `fiber.c` last (D2, D3).
5. Native stage chain and the new fixed point (D4).
6. Seed cut-over (D1).
7. Delete the emitter and its entry together (D5).
8. Switch the linker driver to `rust-lld` (D9) and extend the measured
   link to cover the runtime archive, pthread and the host object.
   Whether that link is self-contained depends on D9a.
