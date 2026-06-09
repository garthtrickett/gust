
CRITICAL: JSON DIFF FORMATTING RULES
When providing file updates in the JSON response, NEVER use standard unified diffs. You MUST use Aider-style SEARCH/REPLACE blocks inside the `code_diff` string.

1. The root of your response MUST be a SINGLE JSON object. NEVER return a JSON array at the root level.
2. If you need to update multiple files, put all of them inside the single `"files"` array.
3. Every change must be formatted exactly like this:

{
  "summary": "Example summary of all changes.",
  "files":[
    {
      "file_path": "src/lib/shared/example-file.rs",
      "code_diff": "<<<<<<< SEARCH\n[exact lines to find including exact indentation]\n=======\n[new code here]\n>>>>>>> REPLACE"
    },
    {
      "file_path": "src/another/file.rs",
      "code_diff": "<<<<<<< SEARCH\n[multiple SEARCH/REPLACE blocks can go in this string if needed]\n=======\n[new code here]\n>>>>>>> REPLACE"
    }
  ]
}


COMMANDS
cargo run -- --test
cc gust_output.c -o gust_program && ./gust_program
cargo clippy --fix --allow-dirty


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
