# Removing the Rust prototype compiler — scoped plan

**Operator direction, 2026-08-21: do this, scheduled after Phase 19.1.**

**Status: completed 2026-08-21.** PR #132 made the prototype removable, PR
#136 projected Phase 19 onto the self-hosted compiler, PR #137 deleted the root
package, and PRs #138, #139, and #141 updated the architecture guidance. This
file is retained as the historical removal record; its deleted-path citations
are not evidence for current compiler semantics.

Investigated by the docs/vision lane. **This is `src/`, `scripts/`, `.github/`
and `justfile` work — not this lane's to execute.** The plan is here so the lane
that owns it starts from an inventory rather than a search.

---

## 1. `src/` is three things, and one is load-bearing

The single most important finding: **"delete `src/`" would break every build.**

| Path | What it is | Verdict |
| --- | --- | --- |
| `src/runtime.c`, `src/runtime/*.c` | The C runtime. `make gust` runs `cat src/runtime.c build/gust_compiler.c > build/gust_final.c`; `make bootstrap` does the same for stages 2 and 3 | **Never delete** |
| `src/runtime/rust/` | Rust *runtime* crate from Phase 17.6 (#44, 2026-08-16), own `Cargo.toml`, guarded by `scripts/phase17_rust_runtime.py` | **Out of scope — a separate decision** |
| `compiler/experiments/cranelift/` | The active Cranelift backend. Also Rust | **Do not touch** |
| The 13 root `.rs` files + root `Cargo.toml`/`Cargo.lock` | The deprecated prototype compiler, package `gust_lexer` | **This is the removal** |

**Exact list:** `src/ast.rs`, `src/codegen.rs`, `src/codegen_runtime.rs`,
`src/lexer.rs`, `src/lib.rs`, `src/main.rs`, `src/parser.rs`, `src/resolver.rs`,
`src/token.rs`, `src/typechecker.rs`, `src/typechecker/monomorphize.rs`,
`src/typechecker/types.rs`, `src/typechecker/visitor.rs`, plus `Cargo.toml` and
`Cargo.lock` at the repository root.

---

## 2. Why it is safe, and why it is worth doing

**It is never built.** No `cargo build`, `cargo test` or `cargo run` against the
root crate appears in any file under `.github/workflows/`. **It could be broken
right now and nothing would report it.**

**It is not in the bootstrap chain.** `README.md` §"The Non-Rust Bootstrap Chain":
*"To build, run, and test Gust, you do not need Rust or Cargo installed."* It is
described there as the *optional* prototype toolchain.

**It is not the differential oracle.** `AGENTS.md` assigns that to MIR-to-C.

**The premise that it is unused is wrong, and that is the argument for removal
rather than against it.** 28 commits touched it in the last 60 days and the most
recent was **2026-08-19** (#74, the `str` equality diagnostic). **A lane is paying
a dual-compiler tax on a compiler that is never compiled.** Every CR in
`TASK_STDLIB.md` that reports "affected: both parsers, both typecheckers" is
paying it too.

---

## 3. What holds it in place, and it is thinner than it looks

**Two guards, and both work by grepping text rather than by building anything.**

- `justfile:21781` — `guard-stdlib-s1-str-equality-diagnostic` asserts the
  rejection string appears in **both** `src/typechecker/visitor.rs` and
  `compiler/typechecker.gst`, with the comment *"both compilers must reject with
  the same words."*
- `justfile:21902` — `guard-stdlib-s1-resource-prerequisites` loops over
  `compiler/lexer.gst src/lexer.rs src/parser.rs` checking that no destructor
  keyword has appeared.

> **The "both compilers agree" invariant is really "both files contain the same
> string."** It is weaker than it reads, and it is precisely why #74 had to edit
> Rust at all. Removing the Rust arm loses nothing that a build ever checked.

**Two workflows path-filter on the removed files** and need those lines dropped:
`.github/workflows/stdlib-s1-str-equality.yml` and
`.github/workflows/stdlib-s1-resource-prerequisites.yml`. Both guards keep
working against the self-hosted compiler alone; the second already guards
`[ -f "$f" ]`, so it degrades safely either way.

---

## 4. Two zone defects change, and one closes

**D-2 closes outright.** It records that *"Rust uses `ends_with(".a")`
(`src/codegen.rs:1766`); the self-hosted compiler uses a substring search"* and
calls it a semantics divergence. **With one compiler there is no divergence.**
Delete the row and record the closure in `SHARED_SEMANTIC_ZONE.md`'s maintenance
section — a defect closed by deletion is still closed.

**D-1 halves.** Its citation list is `src/codegen.rs:71`,
`src/typechecker/types.rs:61` *"and seven other sites; also
`compiler/codegen.gst:658,762,896,1101,1851` and
`compiler/typechecker.gst:4975,5173`."* The defect survives in the self-hosted
compiler and is Phase 19's; only the Rust half of the evidence goes.

---

## 5. Documents to update, ~8 files

`TASK_PHASE19.md` (heaviest — its D-1 evidence is largely Rust sites),
`TASK_STDLIB.md` (CR "affected" lists), `STEP52_RESOURCE_SEMANTICS.md`,
`docs/SHARED_SEMANTIC_ZONE.md`, `docs/STDLIB_SURFACE_FINDINGS.md`,
`docs/ONE_WAY_LEDGER.md` (roughly eight reproductions grep `src/lexer.rs`
alongside `compiler/lexer.gst`), `docs/VISION_RECONCILIATION.md`, `README.md`.

**None of these blocks the deletion.** A citation to a deleted file is a
correction, not a failure — and `SHARED_SEMANTIC_ZONE.md`'s own rule already says
a defect's citations are guaranteed only until the defect is fixed.

---

## 6. Sequencing — and one caution about Phase 19 specifically

**Operator direction is after Phase 19.1.** One thing to weigh when scheduling
within that:

> **`TASK_PHASE19.md` cites the Rust sites as D-1 evidence** —
> `src/codegen.rs:71,128,1762,1808,1843`, `src/typechecker/types.rs:61,439`,
> `src/typechecker.rs:135,172`,
> `src/typechecker/monomorphize.rs:234,254,268,599,722`, and the `ends_with(".a")`
> comparison at `:1766`. **Phase 19 owns D-1, and deleting the Rust compiler
> removes evidence that phase's own roadmap cites.**

That is not a reason to delay past 19.1 — it is a reason to **do the roadmap
edit as part of the removal rather than after it**, so Phase 19 is never in a
state where its cited evidence does not exist. If any later 19.x patch still
needs the Rust sites as a comparison point, it should say so before the removal
lands.

**Suggested order**, each step independently revertible:

1. Drop the Rust arm from the two `justfile` guards; drop the path filters from
   the two workflows. **Land and let CI go green before deleting anything.**
2. Delete the 13 `.rs` files, `Cargo.toml`, `Cargo.lock`. Verify `make gust`,
   `make test`, and `make bootstrap` — none of which should notice.
3. Update `TASK_PHASE19.md`, then the other seven documents. Close D-2 in the
   zone with its closure recorded.
4. `README.md`: the Non-Rust Bootstrap Chain section, and the shell description
   mentioning *"the optional Rust prototype compiler toolchains"*.

**Step 1 before step 2 is the whole discipline** — it is the same A→B→C shape as
Step 5.1: make the thing removable while it still exists, then remove it. A
deletion that lands with its guards still pointing at the deleted files fails in
CI rather than in review.

---

## 7. What is explicitly *not* in scope

- `src/runtime.c` and `src/runtime/*.c` — the C runtime every build depends on.
- `src/runtime/rust/` — Phase 17.6's Rust runtime crate. **Whether that stays is
  a separate question with its own guard**, and it is closer to the C-retirement
  argument than to this one.
- `compiler/experiments/cranelift/` — the active backend.
- The MIR-to-C backend, which is `docs/ROADMAP_TAIL.md` Phases 23–24 and is
  governed by its own exit gates.
