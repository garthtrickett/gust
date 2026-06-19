# Gust Compiler & Lexer

Gust is a minimalist, value-branded, lifetime-tracked programming language designed for high-performance, low-latency applications. It compiles to hardware-aligned, optimized C99, facilitating safe memory reclamation without a garbage collector.

## Core Architecture

- **Bootstrap Compiler (`src/`)**: Written in Rust to act as the primary bootstrapping pipeline. It handles lexical analysis, parsing, type checking, and C99 code generation.
- **Self-Hosted Compiler (`compiler/`)**: Written natively in Gust, achieving full compiler bootstrapping and fixed-point convergence.
- **Value-Branded Lifetimes**: Generates index-based safe memory layouts tied to virtual bump allocation arenas, preventing lifetime escapes at compile time.
- **Cooperative Fiber Runtime**: Fiber-based execution (coroutines) with task schedulers, locks, and channel primitives.

## Project Structure

```text
├── src/                  # Bootstrapping compiler (Rust)
├── compiler/             # Self-hosted compiler source code (Gust)
├── tests/                # Compilation and End-to-End tests
├── flake.nix             # Nix flake for the development environment
├── Cargo.toml            # Rust cargo package configuration
└── LICENSE               # MIT License
```

## Getting Started

### Prerequisites

To build and run the project, ensure you have the following installed:

- [Rust Compiler Toolchain](https://www.rust-lang.org/tools/install) (edition 2024)
- A C Compiler (e.g., `gcc` or `clang`)
- (Optional) [Nix](https://nixos.org/) for the developer shell

### Developer Shell (Nix)

If you use Nix, you can enter the development shell directly:

```bash
nix develop
```

This loads the appropriate compiler tools and provides convenience helpers like `gtl` (run all tests) and `gcf` (clippy fix).

### Running Tests

Run the test suite to verify compiler diagnostics, type-checking rules, and C99 compilation output:

```bash
cargo test
```

To run a specific test with debug logging enabled:

```bash
RUST_LOG=debug cargo test test_self_hosted_topological_sort -- --nocapture
```

### Compiling Gust Source Code

You can compile a Gust source file using the bootstrapping compiler:

```bash
cargo run -- compiler/e2e_bootstrapped_self_target.gst output.c
```

Then, compile and run the generated C code:

```bash
cc output.c -o program -pthread -fsanitize=address,undefined
./program
```

### Diagnostics and AST Dumping

- **Dump the AST** as a serialized structured text format:
  ```bash
  cargo run -- --dump-ast src/main.gst
  ```
- **Dump resolved Type Environments**:
  ```bash
  cargo run -- --dump-types src/main.gst
  ```
# Gust

Gust is a lightweight, strongly-typed programming language designed to compile into highly efficient, structured C code. Written with a strict, expression-based, and modular design, Gust features explicit memory management with zero garbage-collection overhead, a cooperative fiber runtime, and a production-grade bump allocator.

---

## Key Architectural Highlights

* **Self-Hosting Architecture:** The Gust compiler is fully self-hosted, with its core lexing, parsing, namespacing, typechecking, and code generation routines written entirely in Gust itself (`compiler/*.gst`).
* **Fixed-Point Bootstrap Convergence:** The compiler successfully compiles itself recursively through subsequent generations. Compiling the self-hosted compiler using the Rust prototype produces `gust_v2` (C output, compiled to `./gust_v2_bin`). Compiling the codebase again using `gust_v2_bin` produces `gust_v3.c`. Compiling a final time using `gust_v3_bin` produces `gust_v4.c`. The outputs `gust_v3.c` and `gust_v4.c` are 100% byte-for-byte identical, demonstrating absolute determinism and compilation stability.
* **Strict Escape Analysis:** To safeguard against dangling pointers and use-after-free errors, Gust utilizes an escape-analysis engine. Variables are assigned strict compile-time "memory origins" (such as stack, heap, or thread-local scratchpad). The compiler prevents volatile, scratchpad-allocated views from escaping their local functional scopes unless safely duplicated into long-lived memory areas.
* **Cooperative Fibers & Scheduler:** Fast user-space task switching is implemented natively using custom assembly context-switching routines, backed by a hardware-affinity-bound scheduler shard loop.

---

## Getting Started

Gust utilizes a minimalist development shell via Nix, providing pre-configured builds of the Rust compiler, Cargo, GCC compiler tools, GDB, and custom shortcuts.

### 1. Enter the Development Shell
Ensure you have Nix installed with flakes enabled, and run:
```bash
nix develop
```

### 2. Run the Verification Test Suite
Once inside the shell, you can use the pre-configured shortcuts to execute the test suite (which includes the entire multi-stage bootstrapping process):
* **Run all tests (with logs redirected to `to.log`):**
  ```bash
  gtl
  ```
* **Run a specific test (e.g., the bootstrap test):**
  ```bash
  gt-one test_self_hosted_compiler_full_bootstrap
  ```
* **Check formatting and linting rules:**
  ```bash
  gcf
  ```

---

## Compiler Usage Guide

### Compiling with the Rust Prototype (gust_v1)
To compile a single Gust file directly into transpiled C code using the Rust compiler prototype, execute:
```bash
cargo run -- <input_file.gst> [output_file.c]
```
*If no output file is provided, it defaults to writing to `gust_output.c`.*

### Compiling with the Bootstrapped Compiler (gust_v3)
To compile a Gust file using the C-compiled self-hosted compiler, run:
```bash
./gust_v3_bin <input_file.gst> > output_file.c
```

### Compiler Diagnostics & Dumps
The Rust prototype provides two diagnostic flags designed to facilitate ground-truth AST and Type comparisons during compiler validation:

1. **Dump Stable Abstract Syntax Tree (AST):**
   Serializes the parsed AST into a stable, whitespace-indented text representation (stripping volatile source spans) to make it directly diffable against other compilations:
   ```bash
   cargo run -- --dump-ast <input_file.gst>
   ```

2. **Dump Verified Type Database:**
   Serializes the typechecker tables (including resolved variables, alphabetically sorted structures, variant registries, and sorted function signatures) after semantic validation has succeeded:
   ```bash
   cargo run -- --dump-types <input_file.gst>
   ```
