# GEMINI.md: Code Patching & Diff Guidelines

## CRITICAL: JSON DIFF FORMATTING RULES
When providing file updates, you must output a single JSON payload. The pipeline executes updates transactionally: if any single search block fails to match, or if syntax errors are introduced, **the entire patch is aborted and no files are modified on disk**.

---

### 1. Root Structure Rules
* The root of your response MUST be a single, valid JSON object. Do NOT wrap it in a root array.
* If you are editing multiple files, include all of them in the single `"files"` array.

---

### 2. The `"summary"` Field (Git Commit Message)
* The `"summary"` string at the root of your JSON is automatically extracted and used as the **Git commit message** by the pipeline.
* Make this summary clear, concise, and professional (e.g., following Conventional Commits, such as `feat: add auth check middleware` or `fix: resolve crash in user loop`).

---

### 3. Search / Replace Blocks (`code_diff`)
Within the `"code_diff"` string of each file entry, use Aider-style `<<<<<<< SEARCH` and `>>>>>>> REPLACE` blocks.

```json
{
  "summary": "feat: implement rate limiting middleware",
  "files": [
    {
      "file_path": "src/middleware/rate_limit.ts",
      "code_diff": "<<<<<<< SEARCH\nexport function setup(app) {\n  // old logic\n}\n=======\nexport function setup(app) {\n  // new rate limit logic\n}\n>>>>>>> REPLACE"
    }
  ]
}
```

---

### 4. Advanced Block Matching Features

#### A. Elision via Ellipses (`...`)
To avoid outputting large, unchanged blocks of code, you can use `...` in both the SEARCH and REPLACE blocks to skip unchanged lines.
* **Rule**: You must use the exact same number of `...` markers in both the SEARCH and REPLACE blocks.
* **Rule**: The text immediately before and after the `...` must be unique and substantial enough to anchor the match safely. Avoid putting `...` directly next to common characters like single closing braces `}` which are not unique in the file.

*Example:*
```text
<<<<<<< SEARCH
function processUserData(user) {
  console.log("Processing...");
  ...
  saveToDatabase(user);
}
=======
function processUserData(user) {
  console.log("Processing active user...");
  ...
  saveToDatabase(user);
}
>>>>>>> REPLACE
```

#### B. JavaScript / TypeScript AST Fallback (Tier 3.5)
For `.js`, `.jsx`, `.ts`, and `.tsx` files, the patcher features an AST-node fallback. If literal text matching fails, it will attempt to match structural declarations (functions, methods, classes, interfaces) by their names and replace them.
* When editing TS/JS, ensure your search blocks cleanly cover semantic entities (like an entire function or class method) to allow the AST fallback to succeed if the raw text is slightly misaligned.

#### C. Rust AST Fallback (Tier 3.6)
For `.rs` files, the patcher provides AST-node fallback resolution. If literal search matching fails, it attempts to resolve matched item blocks structurally for Rust declarations:
* **Tracked Entities**: Functions (`function_item`), structs (`struct_item`), enums (`enum_item`), traits (`trait_item`), module structures (`mod_item`), and implementation blocks (`impl_item`).
* **Rule**: When targeting Rust, attempt to isolate edits within complete functional bounds or structural items. This ensures that if indentation is shifted or minor line adjustments fail, the patcher can safely find the target entity inside the Rust AST.

#### D. Indentation-Adjusted Match Fallback (Tier 2)
The patcher will automatically adjust leading whitespace differences if your block indentation does not match the file's current nesting structure. However, matching the target indentation exactly is still the safest path to ensure accurate patches.

---

### 5. Syntax Validation & Transactional Safety
The patching tool uses Tree-sitter to validate the syntax of JavaScript, TypeScript, JSX, TSX, and Rust files after applying modifications.
* **Rule**: Do not introduce incomplete or broken syntax. If Tree-sitter detects any syntax errors after applying your patch, the entire transaction will fail, roll back, and abort.
* Ensure every block is completely precise. If you output changes for multiple files and one block fails, none of the files will be modified on disk.


COMMANDS
RUST_LOG=debug cargo test -- --nocapture --test-threads=1
cargo clippy --fix --allow-dirty
cc gust_output.c -o gust_program && ./gust_program
cargo run -- --test


42069

# Rust Style Guide: Sovereign Core & Gust Compiler

This document defines the architectural patterns, coding standards, and style guidelines for Rust development within this project. It is heavily inspired by our functional TypeScript and Kotlin Gatekeeper style guides—focusing on minimal abstraction, locality of behavior, strict expression-based flow, and robust error handling without exception/panic mechanics.

---

## 1. Core Philosophy

### Grug-Brained Simplicity
* **Locality of Behavior (LoB):** The effort required to understand a section of code should be proportional to its physical size. Avoid deep modular nesting or splitting a single logical flow across five files.
* **Minimal Abstraction Principle:** Do not abstract until you have repeated a pattern at least three times. It is significantly cheaper to have duplicate lines than to struggle against the wrong abstraction.
* **Generics Caution:** Restrict the use of generics. Only use them for true container/utility types (e.g., AST structures, Collections, Monads). If a concrete type works, use the concrete type.

### Smart Core, Dumb Shell (Headless SAM)
* **Zero-Copy Performance:** Ensure boundary transfers utilize direct memory access, serialized raw vectors (`Vec<f32>`, `Vec<u32>`), or raw buffers where applicable to bypass garbage collection overhead.

---

## 2. Functional Rust & Expression-Based Flow

Rust is natively expression-based. Capitalize on this to eliminate mutable intermediate state (`mut`) and state-tracking flags.

### Implicit Returns & Bindings
Avoid initializing variables with `let mut` only to assign them inside conditional statements. Assign the conditional block directly to a `let` binding.

**✅ Correct:**
```rust
let value = if condition {
    compute_primary()
} else {
    compute_fallback()
};
```

**❌ Incorrect:**
```rust
let mut value = 0;
if condition {
    value = compute_primary();
} else {
    value = compute_fallback();
}
```

### Pure Calculation vs. Execution (The "Vat" Rule)
* **Mathematical Vats:** Core transformations (Lexing, Parsing, Typechecking, Codegen, Mesh computation) must be mathematically pure. Given the same inputs, they must return the exact same outputs.
* **No Side-Effects in Logic:** Pure logical calculations must never perform disk I/O, access system clocks, or make network calls. Isolate these actions to the outermost caller (e.g., `main.rs`, Web Worker orchestrator).

---

## 3. The "Anti-Manager" Pattern

We do not write object-oriented code disguised as Rust.

* **No Stateless "Service" Structs:** Avoid creating instantiable helper structures like `ValidationManager`, `FormatHelper`, or `CompilerService` that hold zero long-running state.
* **Top-Level and Pure Functions:** Use top-level modular functions or implement pure methods directly on the target data structure (`impl StructName`).

**✅ Correct:**
```rust
pub fn validate_type(expected: &Type, actual: &Type) -> bool {
    // Top-level, stateless, pure calculation
    expected == actual
}
```

**❌ Incorrect:**
```rust
pub struct ValidationManager;

impl ValidationManager {
    pub fn new() -> Self { Self }
    pub fn validate(&self, expected: &Type, actual: &Type) -> bool {
        expected == actual
    }
}
```

---

## 4. Error Handling: Railway Oriented Programming (ROP)

Do not use panics, `unwrap()`, or `expect()` for routine flow control. If a function can fail, that failure is a *valid return type*.

### Error Monads
Functions that can fail must return a `Result<T, E>` or `Option<T>`. Callers are forced by the compiler to handle both the happy and unhappy paths.

**✅ Correct:**
```rust
pub fn resolve_type(&self, t: &Type) -> Result<Type, TypeError> {
    match t {
        Type::Generic(name, args) => {
            let resolved_args = self.resolve_generic_arguments(args)?;
            self.monomorphize(name, &resolved_args)
        }
        _ => Ok(t.clone()),
    }
}
```

**❌ Incorrect:**
```rust
pub fn resolve_type(&self, t: &Type) -> Type {
    match t {
        Type::Generic(name, args) => {
            self.monomorphize(name, args).unwrap() // Catastrophic panic risk
        }
        _ => t.clone(),
    }
}
```

### Domain-Specific Error Types
Define explicit, descriptive error enums with `#[derive(Debug, Clone, PartialEq, Eq)]`.

---

## 5. Unhappy Path First (Flat Control Flow)

Keep your code flat. Use guard clauses, pattern matching, and early returns (`return Err(...)` or `return None`) to prevent your code from drifting into nested indentation hell.

**✅ Correct:**
```rust
pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
    let Expression::Identifier(name) = expr else {
        return self.fallback_evaluation(expr);
    };

    if self.moved_vars.contains(name) {
        return Err(TypeError {
            kind: TypeErrorKind::UseOfMovedVariable,
            message: format!("Use of moved variable: {name}"),
        });
    }

    self.symbol_table.get(name).cloned().ok_or_else(|| TypeError {
        kind: TypeErrorKind::UndefinedVariable,
        message: format!("Undefined variable: {name}"),
    })
}
```

**❌ Incorrect:**
```rust
pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
    if let Expression::Identifier(name) = expr {
        if !self.moved_vars.contains(name) {
            if let Some(t) = self.symbol_table.get(name) {
                Ok(t.clone())
            } else {
                Err(TypeError { ... })
            }
        } else {
            Err(TypeError { ... })
        }
    } else {
        self.fallback_evaluation(expr)
    }
}
```

---

## 6. Functional Iterators

Prefer functional combinators (`map`, `filter`, `fold`, `any`, `all`) over imperative `for` loops ONLY WHEN where they enhance clarity. Do not hesitate to revert to simple imperative loops if the functional pipeline becomes overly complex.

**✅ Correct:**
```rust
let resolved_args: Result<Vec<Type>, TypeError> = args
    .iter()
    .map(|arg| self.resolve_type(arg))
    .collect();
```

---

## 7. Logging & Debugging Standards

We use structured logging with high visibility. All major logical branch transitions (especially inside core calculations) should be logged. We employ an emoji-guided schema to enable rapid parsing of terminal traces.

Instead of trying to guess why a complex monomorphization failed, we can write localized, diagnostic-heavy tracing::debug! calls that dump the entire local variable table, the expected vs. actual type layouts, and active memory origin sets at the precise boundary of failure.
By executing the tests with RUST_LOG=debug cargo test -- --nocapture, we will get a complete step-by-step diagnostic trace leading right up to the panic or failure.

### How to Enable Tracing
The `tracing` and `tracing-subscriber` frameworks are fully integrated. To view structured logs during compilation or testing:
1. Set the `RUST_LOG` environment variable (e.g. `export RUST_LOG=debug` or `export RUST_LOG=info`).
2. Run your cargo commands:
   * **Run tests with logs**: `RUST_LOG=debug cargo test -- --nocapture`
   * **Run compiler with logs**: `RUST_LOG=debug cargo run -- input.gst`

### Logging Initialization
Logging is initialized globally via `gust_lexer::init_logging()`. In test suites and binary entry-points, this is called safely (preventing multiple registrations via `try_init()`).

### Emoji Legend
* `📥` **Action Dispatched:** Event incoming to Worker/Engine boundary.
* `🔄` **State Changed:** State transitions or monomorphization resolutions.
* `⚙️` **Execution:** Side effects (file writes, arena growth allocations).
* `🗄️` **Memory / Registry:** Type additions to registry tables or variable scoping modifications.
* `✅` **Verification:** Successful verification, parser compliance, or compile completion.
* `❌` **Error:** Caught compile validation or runtime issues.
* `👁️` **Tracing:** Localized diagnostics.

**Example Implementation Pattern:**
```rust
pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> {
    tracing::debug!("📥 Starting validation pass for program structure.");
    for stmt in &program.statements {
        self.check_statement(stmt).map_err(|e| {
            tracing::error!("❌ Validation failed: {}", e.message);
            e
        })?;
    }
    tracing::info!("✅ Program validation complete. System is safe.");
    Ok(())
}
```

---

## 8. Testing Standards

Maintain a multi-layered testing topology:

* **Layer 1: Unit Tests (`cargo test`):** Put unit tests in the same file as the tested components using a `tests` module block with `#[cfg(test)]`. Target pure calculations and lexer/parser invariants.
* **Layer 2: Integration / E2E Tests:** Keep integration and end-to-end user flows inside a separate `/tests` directory (e.g., `tests/compile_tests.rs`, `tests/e2e_tests.rs`).
* **Strict Assertion of Invariants:** Use `assert_eq!`, `assert!`, and `matches!` pattern testing directly rather than mock structures. Avoid mocking libraries unless strictly testing I/O boundaries.

---

## 9. Diagnostic CLI Flags & Self-Hosting Roadmap

The `gust_v1` compiler provides two diagnostic command-line flags to assist with ground-truth verification during the self-hosting phase:

### `--dump-ast`
* **Purpose**: Intercepts the pipeline directly after parsing.
* **Behavior**: Walking the parsed Abstract Syntax Tree (AST), this flag serializes it into a highly deterministic, stable, human-readable indented text structure. Volatile spans are stripped to ensure the output remains perfectly diffable against the self-hosted parser in Phase 3.
* **Usage**:
  ```bash
  cargo run -- --dump-ast src/main.gst
  ```

### `--dump-types`
* **Purpose**: Intercepts the pipeline directly after typechecking.
* **Behavior**: Extracts the populated type checking databases (including resolved variable types, alphabetically sorted struct layouts, enum variant listings, and alphabetically sorted function signatures) and serializes them. This acts as our semantic ground-truth reference database for the self-hosted typechecker in Phase 4.
* **Usage**:
  ```bash
  cargo run -- --dump-types src/main.gst
  ```
