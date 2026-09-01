# Gust Compiler

> **Gust moves danger out of your hands and into the compiler's.**
>
> In C and Zig, correctness is your job — the language hands you sharp tools and trusts you not to slip. In Rust the compiler checks correctness, but *you* still write the proof: lifetimes, variance, `Send`/`Sync`. The burden moved; it did not leave.
>
> Gust takes a third path. Safety obligations are discharged by **structure** rather than annotation, and there is deliberately **one way to do things**. You should be able to write correct systems code without becoming a lifetime theorist, and without a garbage collector.

Gust is a minimalist, self-hosted, expression-based systems language built around "Grug-brained simplicity." It targets products where **stability outranks peak performance**: long-running services, edge and embedded work, and anywhere GC pauses hurt but C-level hand-tuning is not worth its risk.

## The failure-mode argument

The design is clearest if you ask what happens when you get it wrong.

| Language | You get it wrong → |
| --- | --- |
| C / Zig | Undefined behaviour, corruption, possibly exploitable |
| Rust | It does not compile — safe, but paid for in developer time |
| Go | Runtime panic, or a GC pause at the wrong moment |
| **Gust** | **You hold memory longer than necessary** |

Region-based memory is coarse: an arena frees as a unit, so retention is bounded by region lifetime. That is a real cost and it is the one we choose to pay. It converts a *correctness* risk into a *resource-usage* risk, which is the right trade when stability is the product requirement.

## What the compiler carries — and what it does not

Being explicit about the boundary is worth more than claiming it is total.

**The compiler carries:** memory safety, resource and scope-exit lifetimes, move and double-free analysis, explicit error paths, type and target layout, function ABI, and the native runtime boundary.

**You still carry:** logic errors, protocol misuse, and algorithmic correctness. Gust does not pretend a type system can hold those without becoming the proof-writing burden it set out to remove.

## Memory and concurrency model

*   **Value-Branded Lifetimes (Arenas):** Safe, index-based memory bound statically to virtual memory arenas. The region is visible in the type, so the reasoning is *local* — there are no global lifetime relationships to infer or satisfy.
*   **Linear & Move-Only Types:** Compile-time linear move-analysis and double-move protection on resources like strings, slices, and arenas.
*   **Cooperative Fibers:** Low-overhead, user-level cooperative threading managed by a high-density, multi-shard thread-scheduler.
*   **Built-in Synchronization:** Co-routine safe synchronization primitives (mutexes, channels, and pools) engineered to operate seamlessly across fiber-switching boundaries.

## Why LLMs write Gust well

This is a consequence of the design, not its premise. Locality of Behavior, no macros, no indentation sensitivity, and the arena being visible in the type mean the information needed to edit a span is present *in that span*. A model does not have to reconstruct invariants that live three files away — the same property that makes the language readable for a human.

That framing is deliberate and it is the one that survives. `docs/VISION.md` §0.1 argues the stronger position — that Gust targets software "never read by people" — and an earlier draft drew a design licence from it ("verbosity is free"). That licence is withdrawn: the readership claim is a market observation about what to build first, not permission for ceremony in the language. `docs/VISION_RECONCILIATION.md` §3.1 records the conflict and its resolution; the operative rule is *explicit exactly where the explicitness is the artifact, inferred everywhere else*.

## Two backends, and why

Gust compiles to native executables through Cranelift by default. The retained
C99 backend is deprecated and selected explicitly with `--backend c` or
`--backend mir-to-c`; both spellings remain accepted and byte-identical during
Phase 23, with backend removal scheduled for Phase 24. Its focused semantic-
oracle role remains live until that removal.

That portability has a semantic cost worth stating plainly. Transpiling to C means inheriting **C's abstract machine**, not just its syntax: pointer provenance, effective-type rules, and signed-overflow latitude included. An arena-and-index model carves differently-typed objects out of one allocation and reconstructs pointers from a base and an offset, which is precisely the pattern those rules punish. Code that is provably correct under Gust's model can still be miscompiled at `-O2` by a C compiler applying rules Gust never agreed to.

The native Cranelift backend exists to close that gap. It is **not** a performance play. It is what makes "the compiler carries the danger" actually true, by expressing Gust's memory model in a backend that honours it rather than laundering it through C's. Cranelift's memory model is deliberately concrete — loads and stores with alias information the compiler supplies — rather than an abstract machine with undefined-behaviour-driven optimisation latitude.

The deprecated C backend remains a temporary compatibility path and the focused
semantic oracle. The C bootstrap seed and host-C bootstrap chain are separate:
their retirement is deferred to Phase 25, not implied by Phase 24 backend
removal. A differential test suite keeps the two backends honest against each
other. Cranelift never silently falls back to C: an unavailable or rejected
native backend is a compilation failure, and choosing C is always explicit.

---

## The Non-Rust Bootstrap Chain

The self-hosting bootstrap chain remains C-only. Building the default
three-artifact native distribution from source also builds the Cranelift worker
and therefore requires the pinned Rust toolchain and Cargo. Users of an
installed Gust distribution do not need Rust or Cargo.

Gust is fully self-hosted, meaning the compiler is written in Gust itself. To break the traditional "chicken-and-egg" bootstrap loop without forcing a Rust dependency on end-users, Gust utilizes a C-based bootstrap pipeline:

The deprecated root Rust prototype compiler has been removed. Rust remains in
two deliberately separate components: the active Cranelift backend under
`compiler/experiments/cranelift/` and the Phase 17 runtime crate under
`src/runtime/rust/`. Neither participates in the explicit C bootstrap chain.

```
[Seed Compiler Source] (gust_v4.c)
        │
        ▼  (Compiled with Host C Compiler)
[Bootstrap Binary] (gust_bootstrap)
        │
        ▼  (Transpiles latest compiler source code)
[Transpiled C Code] (build/gust_compiler.c)
        │
        ▼  (Assembled with src/runtime.c)
[Production Compiler] (gust)
```

1.  **Stage 0 (The Seed):** `gust_v4.c` is a pre-compiled, fully converged C version of the self-hosted compiler committed directly to the repository.
2.  **Stage 1 (The Bootstrap):** Running `make` compiles this seed using the host's standard C compiler (`cc`), producing a temporary bootstrap compiler binary (`gust_bootstrap`).
3.  **Stage 2 (Self-Hosting):** The `gust_bootstrap` binary compiles the latest modular Gust compiler source code (`compiler/test_runner_entry.gst`) and outputs clean C code (`build/gust_compiler.c`).
4.  **Stage 3 (Assembling the Runtime):** The compiled compiler code is concatenated alongside Gust's standard runtime library (`src/runtime.c`) and compiled into the final, optimized `gust` compiler executable.

---

## Getting Started

### Prerequisites
*   A standard-compliant C compiler (such as `gcc` or `clang`).
*   The `make` utility.
*   POSIX threads (`pthread`) support.
*   Rust 1.97.1 and Cargo when building the default native distribution from source.

### Building the Compiler
To clean old artifacts and perform the full multi-stage bootstrap build, execute:

```bash
make clean
make
```

This produces the production-ready sibling package under
`build/phase10-package/bin/`: `gust`, `gust-native-backend`, and
`gust-runtime-package.a`. The three files are one relocatable unit; keep them
together. The root `gust` binary is also produced as the self-hosted compiler.

Compile a program through the default Cranelift route with:

```bash
build/phase10-package/bin/gust program.gst
```

The executable defaults to the source path with the final `.gst` removed. Use
`-o <path>` to choose another path. The deprecated C compatibility choices,
`--backend c` or `--backend mir-to-c`, remain accepted through Phase 23 and
emit byte-identical C to standard output; backend removal is scheduled for
Phase 24. Bootstrap-C retirement is a separate Phase 25 change.
There is no automatic fallback between the native and C routes.

### Running the Test Suite
To verify the compiler's typechecker, code generator, and FFI standard library runtime, execute:

```bash
make test
```

This compiles, links, and runs the end-to-end verification suites, printing a success confirmation when complete:

```text
✅ Collections E2E Passed
✅ Formatting & Arena E2E Passed
```

### Installation
To install the complete three-artifact sibling package into your system's
binary path (defaults to `/usr/local/bin`), run:

```bash
make install
```

*(You can customize the installation path by specifying `PREFIX`, e.g., `make install PREFIX=$HOME/.local`).*

---

## Reproducible Development (Optional)

If you prefer a sandboxed, deterministic development environment, a reproducible Nix flake is available in the repository.

1.  **Enter the Nix development shell:**

```bash
    nix develop
```

    This loads GCC, GNU Make, Python 3, and the Rust tools used by the active
    Cranelift backend and Rust runtime component (`rustc`, `cargo`,
    `rust-analyzer`, and `rustfmt`).

2.  **Run the repository guards:**
    Compiler and backend validation is exposed through the `just` recipes and
    the phase-specific guards documented in `AGENTS.md`. There is no root Cargo
    package or Rust prototype test suite.

```bash
    just --list
```

---

## Directory Structure

*   `compiler/` - The complete, modular self-hosted Gust compiler source files (written in Gust).
    *   `test_runner_entry.gst` - The main entry point of the self-hosted compiler.
    *   `lexer.gst`, `parser.gst`, `typechecker.gst`, `codegen.gst` - Core compiler passes.
    *   `resolver.gst` - Recursive module dependency and import graph resolver.
    *   `experiments/cranelift/` - The active Rust implementation of the native Cranelift backend.
*   `src/runtime.c` - The aggregate C runtime source linked into the self-hosted compiler and generated programs.
*   `src/runtime/` - The standard runtime C library. Contains low-level fiber context switches, the POSIX thread pool, arena allocators, and collections helpers.
    *   `rust/` - The separately guarded Phase 17 Rust runtime component; not the removed prototype compiler.
*   `tests/` - The end-to-end and integration tests written in Gust.
*   `Makefile` - The primary build automation driver.
*   `gust_v4.c` - The stable, converged self-hosting bootstrap compiler C seed.
