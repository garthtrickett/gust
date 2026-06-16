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

