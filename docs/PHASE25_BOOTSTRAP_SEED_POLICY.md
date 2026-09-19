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

## D3 — `fiber.c` specifically · *lane* · **OPEN: three routes, none free**

719 lines carrying **eight blocks of inline assembly** for context switching,
plus pthread. The one file where the block is capability, not sequencing, and
the block is measured: there is no `asm` construct anywhere in
`compiler/lexer.gst`, `compiler/parser.gst`, `compiler/codegen.gst` or the
spec, and 26.1 does not add one.

Three routes, to be decided on measurement rather than here:

- **Rust `global_asm!`.** The assembly ports as assembly. Lowest risk, and the
  default if the others do not measure well. Cost: keeps a Rust component in
  an otherwise Gust runtime, so the second toolchain stays mandatory.
- **`swapcontext`/`makecontext` via `extern func`.** POSIX, needs no assembly
  at all, so it is expressible in Gust today. Cost: slower, obsolescent, and
  removed on some platforms — needs measuring against the current fiber
  benchmark before it is credible.
- **Add inline assembly to Gust.** Honest, and a genuine language feature with
  a Phase 26-sized design question attached. Out of scope for Phase 25 unless
  the other two both fail.

Sequence it **last** of the eight regardless, behind the files with cheaper
parity evidence. `gust_context_switch` and `gust_scheduler_*` are exported
into every binary, so D2's mandatory-not-optional finding applies here too.

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

## D9a — is libc-dev acceptable, or must the link be self-contained? · **operator** · *substantially narrowed*

This row previously offered two tiers as if both were available. The
measurement above shows they are not.

- **Tier 2 — gnu target, libc-dev present, no C compiler.** Largely
  **illusory** with a stock toolchain: rustc will not produce this link
  without Gust supplying distro-specific library search paths itself. Reaching
  it is a project, not a flag.
- **Tier 3 — musl, `-C linker-flavor=ld.lld`, static-pie.** Works today,
  measured, no C artifacts at all. Costs musl libc behaviour and static
  linking, with the binary-size and `dlopen`/NSS consequences that implies.

So the operator's question is no longer "which tier" but the blunter one:
**is musl-static an acceptable supported configuration for the artifact the
gate is proved against?** If yes, the gate is reachable now. If no, the gate
needs rewording, because a C-free gnu link is not a flag away.

Either answer is fine; what is not fine is closing the phase without picking,
which is the shape of defect Phase 24 spent five patches on.

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
4. Define and guard the freestanding Gust subset the runtime must be written
   in (D2's first obligation), then runtime to **Gust** file by file behind
   parity evidence — `scratch.c`, `strings.c`, `host_io.c` first to exercise
   the subset, `arena.c` behind its no-allocate guard, Rust as the per-file
   fallback. Delete `approved_scalar_imports.c` rather than rewriting it.
   `fiber.c` last, on D3's open routes.
5. Native stage chain and the new fixed point (D4).
6. Seed cut-over (D1).
7. Delete the emitter and its entry together (D5).
8. Make `cc` optional rather than required (D9): keep `$CC` honoured, and
   prove the gate with a musl + `rust-lld` link in the D8 job. Extend the
   measured link to cover the runtime archive, pthread and the host object —
   none of which the `std`-only measurement covered.
