## 10. Gust Style Guide: Branding & Ephemeral Views Consistency

When writing or editing Gust (`.gst`) programs, you must strictly adhere to the following memory-safety and type-safety constraints enforced by the Gust typechecker.

### A. Ephemeral View Constraints on Structs
* **Rule:** Unbranded structs **cannot** contain ephemeral view types (such as `str` or `[]byte`). 
* **Action:** If a struct contains a `str` or slice field, it **must** be declared as a branded struct template.

```gust
// ❌ Incorrect (Typechecker will reject due to unbranded 'str' field)
type Test struct {
    path: str
}

// ✅ Correct (Branded template allowed to hold ephemeral views)
type Test[ctx] struct {
    path: str
}
```

### B. Strict Brand Propagation Rule
* **Rule:** Once a struct is declared with a brand parameter (e.g., `MyStruct[ctx]`), **every single reference** to that struct in the program must propagate the brand argument.
* **Why:** Referencing the raw template name `MyStruct` without its brand inside variable declarations, function parameters, or container types (like `std.Vector`) strips the brand. The compiler resolves it with an empty brand (`None`), triggering a **Brand Nesting Restriction violation** or an unbranded ephemeral error.

```gust
// ❌ Incorrect (RHS/LHS and vectors use unbranded 'Test' names)
type Test[ctx] struct {
    path: str
}
func run_test(ctx: &Arena, t: Test) int { ... } // ERROR: Unbranded parameter
func main() {
    mut tests: std.Vector[Test, ctx] := std.VectorNew(ctx); // ERROR: Unbranded vector element
    mut t1: Test; // ERROR: Unbranded variable
}

// ✅ Correct (All types propagate '[ctx]')
type Test[ctx] struct {
    path: str
}
func run_test(ctx: &Arena, t: Test[ctx]) int { ... } // CORRECT: Branded parameter
func main() {
    mut tests: std.Vector[Test[ctx], ctx] := std.VectorNew(ctx); // CORRECT: Branded vector element
    mut t1: Test[ctx]; // CORRECT: Branded variable
}
```
### C. Flat Function Scope & C-Redefinition Invariants
* **Rule:** All variables declared within a single function block (such as `func main()`) must have completely unique names across that entire block, even if they reside in separate logical phases, test steps, or conditional structures.
* **Why:** The Gust-to-C transpiler outputs variable declarations directly into flat C function scopes. Unlike more permissive high-level languages, C strictly prohibits redefining a variable name within the same block scope [2]. Attempting to declare `mut x` twice within the same function will compile cleanly in the Gust parser but trigger a fatal C compiler `redefinition of 'x'` error during the native compilation phase [2].
* **Action:** 
  * Never copy-paste test scaffolding blocks that reuse identical variable names (e.g., `empty_prog_vec` or `empty_prefixes`) [2].
  * Always append descriptive, context-specific suffixes to temporary test variables (e.g., use `empty_prog_vec_tl` and `empty_prefixes_tl` for thread-local tests, and `empty_prog_vec_dup` for deduplication tests) [2].

```gust
// ❌ Incorrect (Will transpile to C redefinitions in main's flat scope)
func main() {
    // Step 1
    mut empty_prog_vec: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    ...
    // Step 2 (Scaffolding copy-pasted)
    mut empty_prog_vec: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx); // C ERROR: Redefinition
}

// ✅ Correct (Unique names per logical context)
func main() {
    // Step 1
    mut empty_prog_vec_dup: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    ...
    // Step 2 
    mut empty_prog_vec_tl: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx); // Safe C transpilation
}

```

### D. Arena-Stored Vector Accessor Migration Pattern
* **Rule:** High-level compiler logic should not introduce new direct arena-to-vector casts such as `&ctx[some_index] as *std.Vector[...]` when a safe branded reference accessor can express the same operation.
* **Why:** Step 4.4 standardizes collection access around compiler-verified references before the later unsafe-gating phase. This keeps compiler traversal code aligned with branded lifetime checks while avoiding a broad raw-cast ban before Step 5.1.
* **Action:** In current compiler code, prefer a simple safe value-read pattern first: copy the arena-stored vector through `ctx[vector_index]`, then use normal vector indexing. Keep `ctx.get_ref(...).GetRef(...)` migration deferred until method lookup on branded reference receivers is fully supported in compiler sources. Keep low-level legacy casts only where a later migration step has not reached that file yet.

```gust
// ❌ Legacy migration target
unsafe {
    mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[stmt_idx] = (*statements_vec)[0];
}

// ✅ Preferred Step 4.4 compiler-source pattern for now
mut statements_vec: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
ctx[stmt_idx] = statements_vec[0];
```

### E. Step 4.4 Checkpoint Validation Discipline
* **Rule:** Step 4.4 migration patches should be medium-sized coherent checkpoints, not microscopic edits. Each checkpoint must be large enough to justify the full validation cost, but small enough to revert or bisect cleanly.
* **Accessor Contract:** Before migrating compiler internals, keep the additive accessor surface stable: legacy `.Get()`, additive `.get_opt()`, `Vector.GetRef`, `std.VectorGetRef`, and `HashMap.GetRef` must continue to coexist.
* **Inventory Before Enforcement:** Use `make report_high_level_raw_collection_casts` to inventory remaining high-level compiler raw casts. This target is report-only during Step 4.4. Do not convert it into a failing guard until the relevant file or migration slice is clean.
* **Migrated Slice Guards:** Once a coherent migration slice is clean, add a narrow guard for only that slice and wire it into `make test`. For example, `guard_step44_low_risk_entry_raw_casts` protects the first low-risk entrypoint slice, `guard_step44_typechecker_aux_raw_casts` protects migrated typechecker auxiliary test entries, `guard_step44_typechecker_types_raw_casts` protects the typechecker type-regression entry, `guard_step44_codegen_initializer_raw_casts` protects the codegen initializer regression entry, and `guard_step44_typechecker_early_raw_casts` protects the first production typechecker slice without blocking the still-unmigrated production `codegen.gst` and later `typechecker.gst` work.
* **Checkpoint Commands:** Before committing any Step 4.4 patch that touches compiler, runtime, tests, Makefile validation, or bootstrap-sensitive files, run:

```bash
make
make report_step44_accessor_contract
# Run the focused gt-one-gst commands printed by report_step44_accessor_contract.
make test
make bootstrap
git diff --check
```

* **Known Red Tests:** If the full suite has pre-existing failures, they must be explicitly documented before the checkpoint. A Step 4.4 patch may only proceed when it introduces no new full-suite failures and `make bootstrap` still converges.
## TOOL USE CONSTRAINTS & DISCIPLINE
- **Prohibition of Execution Tools**: You are strictly prohibited from calling any command execution, bash shell, terminal, or system-running tools (such as `vm_shell:execute_bash` or any equivalent system command triggers).
- **Allowed Tool Scope**: You must only use information-retrieval and text-generation tools (such as `google:search` and `browsing:browse` to gather context, and text responses to supply code patches). 
- **User-Led Verification**: All compilation, tests, and command execution must be left entirely to the user. Do not attempt to run tests or compile code yourself.

# GEMINI.md: Code Patching & Diff Guidelines

## IMPORTANT
For each change write out a json patch in a code block according to below format outlined in "Step 2: Update Parser and Codegen to Transpile References as C Pointers"
If there is more than one block of changes write out more than one code block with a json patch in it for each change in that file


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



Updating tree sitter for helix
git add .
git commit
cd ~/nixos-config  # or cd /etc/nixos
nix flake update tree-sitter-gust
rebuild
reopen helix

make gust to.log 2>&1


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
