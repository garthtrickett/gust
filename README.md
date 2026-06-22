# Gust Compiler

> **Why Gust? Because LLMs shouldn't fight the borrow checker.**
> 
> Traditional systems languages were designed for human hands typing on keyboards, leading to complex abstractions, implicit macros, and indentation dependencies that cause AI code generation to hallucinate or slip.
> 
> Gust is built from the ground up with Locality of Behavior (LoB) and strict monadic typing. It eliminates global lifetime complexity using regional arenas and forces explicit error paths. The result? A language that feels natural for a human to read, but functions as a deterministic, bulletproof sandbox for an AI to write.

Gust is a minimalist, self-hosted, expression-based programming language that transpiles directly to clean, standard C99. It is designed around "Grug-brained simplicity," focusing on locality of behavior, minimal abstraction, and robust compile-time safety invariants without garbage collection overhead.

The language features a unique memory and concurrency model:
*   **Value-Branded Lifetimes (Arenas):** Safe, index-based memory management bound statically to virtual memory arenas.
*   **Linear & Move-Only Types:** Compile-time linear move-analysis and double-move protection on resources like strings, slices, and arenas.
*   **Cooperative Fibers:** Low-overhead, user-level cooperative threading managed by a high-density, multi-shard thread-scheduler.
*   **Built-in Synchronization:** Co-routine safe synchronization primitives (mutexes, channels, and pools) engineered to operate seamlessly across fiber-switching boundaries.

---

## The Non-Rust Bootstrap Chain

To build, run, and test Gust, **you do not need Rust or Cargo installed on your system.**

Gust is fully self-hosted, meaning the compiler is written in Gust itself. To break the traditional "chicken-and-egg" bootstrap loop without forcing a Rust dependency on end-users, Gust utilizes a C-based bootstrap pipeline:

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

### Building the Compiler
To clean old artifacts and perform the full multi-stage bootstrap build, execute:

```bash
make clean
make
```

This produces the production-ready `gust` compiler binary in your root directory.

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
To install the compiled `gust` binary into your system's binary path (defaults to `/usr/local/bin`), run:

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

    This automatically loads a shell pre-configured with GCC, GNU Make, Python 3, and the optional Rust prototype compiler toolchains (rustc, cargo, rust-analyzer).

2.  **Run Rust-based tests (for compiler developers):**
    If you are modifying the original Rust prototype compiler located in `src/`, you can run the Rust-based test suite inside the Nix shell:

```bash
    cargo test
```

---

## Directory Structure

*   `compiler/` - The complete, modular self-hosted Gust compiler source files (written in Gust).
    *   `test_runner_entry.gst` - The main entry point of the self-hosted compiler.
    *   `lexer.gst`, `parser.gst`, `typechecker.gst`, `codegen.gst` - Core compiler passes.
    *   `resolver.gst` - Recursive module dependency and import graph resolver.
*   `src/` - The original Rust-based prototype compiler source files (used optionally by compiler developers to generate updated bootstrap seeds).
*   `src/runtime/` - The standard runtime C library. Contains low-level fiber context switches, the POSIX thread pool, arena allocators, and collections helpers.
*   `tests/` - The end-to-end and integration tests written in Gust.
*   `Makefile` - The primary build automation driver.
*   `gust_v4.c` - The stable, converged self-hosting bootstrap compiler C seed.
