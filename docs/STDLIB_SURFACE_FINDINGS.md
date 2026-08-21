# Stdlib Surface Findings

Handoff-document premises checked against the compiler.

Verified 2026-08-19 against `6c94728d` (`codex/phase18-4-relocations`) using the
`gust` binary built at repository root — it is gitignored, not committed. Every
claim below has a reproduction.

Every file cited here was byte-identical between `6c94728d` and `19ddabde`
(`main` at the time of writing); Patch 18.4 touched only target and relocation
files. **One-compiler amendment, 2026-08-21:** PR #137 removed the deprecated
root Rust prototype. Current-semantic evidence below now cites the self-hosted
compiler; the removed implementation survives only where its historical
divergence explains a closed finding.

The handoff document's stdlib task list rests on four factual premises. Three
are wrong, and the fourth has a root cause the document does not name. The
proposed merge order (§31) is wrong as a direct consequence.

---

## F1 — `str` length, byte access, and slicing already exist

The document's Stdlib Task 1 (§9.1–9.3, merge-order PR 1 and PR 2) proposes
building these. They are present.

| Operation | Status | Evidence |
| --- | --- | --- |
| byte length | present | `len(s)` accepts one argument and returns `int` — `compiler/typechecker.gst:3458-3471`; codegen reads `.len` |
| byte access | present | `std_str_byte_at` — `src/runtime/strings.c:27` |
| slicing | present | `std_str_slice` — `src/runtime/strings.c:16` |
| equality helper | present | `std_str_eq` — `src/runtime/strings.c:10` |
| find / trim / split | present | `src/runtime/strings.c:35,46,61` |

`len(s)` already means **byte length**, which is what §9.1 asks for and what
`VISION.md` §33 requires ("Low-level length and slicing semantics are
byte-based").

All three string helpers are already registry-owned Phase 17 runtime symbols
(`p17_helper_std_str_eq`, `p17_helper_std_str_slice`,
`p17_helper_std_str_byte_at` in `scripts/cranelift_feature_registry.json`,
reachability `runtime_public_surface`).

**Consequence:** PR 1 and PR 2 of the document's merge order are largely
redundant. What remains of Task 1 is F2 and F3.

---

## F2 — `str == str` typechecks and emits invalid C

The document (§9.4) describes this as the MIR-to-C path "trying to compare
underlying C structs". Confirmed, and it is worse than a wrong answer: it does
not compile.

```gust
func main() {
    mut a: str := "PING";
    mut b: str := "PING";
    if a == b { os.LogStr("equal"); } else { os.LogStr("not equal"); }
}
```

The typechecker accepts it. Codegen emits:

```c
Slice_unsigned_char a = ((Slice_unsigned_char){ (unsigned char*)"PING", 4 });
Slice_unsigned_char b = ((Slice_unsigned_char){ (unsigned char*)"PING", 4 });
if ((a == b)) {
```

`==` on two struct values is not valid C. The failure surfaces from the host C
compiler, not from Gust, so the diagnostic names generated C rather than the
user's source.

**Ownership:** `VISION.md` §16 — "Gust does not support user-defined operator
overloading. The operator set is compiler-owned." Deciding what `==` means for
`str` is therefore a shared-zone semantic change, not a stdlib fix. The
document's §9.4 offer to let the Stdlib Agent own it "if it can be corrected in
the frontend" contradicts the repository's stated authority model.

**Consequence:** the document schedules this last (PR 11). It is the only real
gap in Task 1 and should be early — with the cheap half (reject it with a
stable Gust diagnostic) separable from the semantic half (make `==` mean content
equality).

---

## F3 — Brand identity is inferred from identifier spelling

This is the root cause the document does not name. It is shared by Task 3
(§11, branded collection consistency) and Task 4 (§12, Clone arena references).

The self-hosted compiler hardcodes identifier names treated as arena brands.
The generated inventory owns the exact current vocabularies and locations:

```text
compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md
  five compiler/codegen.gst sites
  four compiler/typechecker.gst sites
```

A variable whose **name** is one of these is treated as an arena and has `&`
prepended at call sites, regardless of its declared type.

Reproduction — the only difference between these two programs is the variable's
name:

```gust
func probe(s: str) int { return std.str_byte_at(s, 0); }
func main() {
    mut a: str := "PING";      // name is in brand_bases
    os.LogInt(probe(a));
}
```
emits `os_LogInt(probe(&a));` — and `cc` rejects it:

```
error: incompatible type for argument 1 of 'probe'
```

```gust
    mut b: str := "PING";      // name is not in brand_bases
    os.LogInt(probe(b));       // emits probe(b) — correct
```

Measured across names: `a` is broken; `b`, `c`, `s`, `x`, `arg`, `val`, `zz`,
`aa`, `one`, `two`, `three` are all correct. The defect tracks the identifier,
not the type, not the declaration form (`a := …`, `mut a := …`, and
`mut a: str := …` all fail identically).

### F3a — historical compiler-rule divergence — **closed 2026-08-21**

The removed Rust prototype used an `ends_with(".a")` rule while the self-hosted
compiler used substring matching. Those were observably different rules. PR
#137 removed the deprecated prototype, closing shared-zone D-2 by deletion.
There is now no second compiler frontend whose matching rule can diverge. The
self-hosted substring rule is still live and remains part of F3/D-1.

### F3b — the list is duplicated inside the compiler, and it is in the bootstrap seed

The current generated inventory records nine occurrences across
`compiler/codegen.gst` and `compiler/typechecker.gst`.

Because `gust_v4.c` is the committed converged seed, correcting this is a
self-hosted, bootstrap-sensitive change.

**Consequence:** the document's §4 grant to the Stdlib Agent of "small
frontend fixes that preserve existing semantics" would, applied literally,
authorize an agent to start here. It must not. This is shared-zone work with
Cranelift/compiler ownership, and it blocks Tasks 2, 3, and 4.

---

## F4 — String bounds failures abort the process

`std_str_slice` (`src/runtime/strings.c:16-25`) and `std_str_byte_at`
(`src/runtime/strings.c:27-33`) both do:

```c
printf("std.str_byte_at bounds check failed\n");
exit(1);
```

The document's §9.2 requires "out-of-range is safely handled".
`VISION.md` §34 requires that a panic "terminates the current request, task, or
job — not the complete deployment". `exit(1)` from a fiber terminates the
process.

**Ownership:** these are Phase 17 runtime symbols with declared identity. Changing
their failure behaviour changes the runtime contract — shared zone.

---

## F5 — Every `std.*` name is a Phase 17 runtime symbol

`std.X` resolves through the compiler's registered namespace to the exported
`std_*` surface. There is no `.gst` standard-library source; the stdlib **is**
the runtime's public C surface plus compiler builtins.

Phase 17 made that surface compiler-owned: `scripts/cranelift_feature_registry.json`
carries a `symbol_identity` / `reachability` / `owning_phase17_entry_id` row per
helper. Adding one `std.*` function therefore requires a registry row — and the
handoff document's §4 assigns that registry to the **Cranelift Agent**.

**Consequence:** "the Stdlib Agent owns stdlib APIs" and "the Cranelift Agent
owns the parity registry" cannot both hold without an explicit protocol. Every
new stdlib symbol is a cross-lane transaction.

---

## F6 — MutexGuard is blocked by documented, unfinished prerequisites

`STEP52_RESOURCE_SEMANTICS.md` lists eight required semantic states for
generalized linear resources. This section originally recorded two as unmet.

**Corrected 2026-08-20**, after checking both against the compiler:

- item 6 — "`defer` must have explicit AST/typechecker representation" — is
  **met**. `Defer` is an AST node and the typechecker handles it;
- item 2 — the `Resource` machinery being inert — has **not** been re-verified
  and stays recorded as open. Note that lifecycle enforcement itself is not
  inert: it runs and rejects an unclosed directory handle. What is missing is
  that the obligation is keyed to a hardcoded directory predicate.

`VISION.md` §27 additionally marks shared ownership as **open decision OD-3**.

`STEP52_RESOURCE_SEMANTICS.md` was last modified 2026-06-28, before Phase 15
closed (`TASK.md` "Immutable Phase 15 Completion Record" records patches 15.1–15.15 DONE). It is the document an
agent would consult for authoritative resource state and it is stale.

**Consequence:** the document's §20 stop condition will fire. Better to schedule
the prerequisite audit than to discover it at task 7.

---

## Reproduction

```bash
cd /tmp
cat > probe.gst <<'EOF'
func probe(s: str) int { return std.str_byte_at(s, 0); }
func main() {
    mut a: str := "PING";
    mut b: str := "PING";
    os.LogInt(probe(a));
    os.LogInt(probe(b));
    if a == b { os.LogStr("equal"); }
}
EOF
/path/to/gust probe.gst > probe.c
grep -n 'probe(&\?a)\|probe(&\?b)\|(a == b)' probe.c
cat /path/to/src/runtime.c probe.c > probe_final.c
cc -I/path/to/src -o /dev/null probe_final.c -lpthread -lm
```

Expected — confirmed 2026-08-19:

```
probe.c:60:    os_LogInt(probe(&a));
probe.c:61:    os_LogInt(probe(b));
probe.c:62:    if ((a == b)) {

error: incompatible type for argument 1 of 'probe'
error: invalid operands to binary == (have 'Slice_unsigned_char' and 'Slice_unsigned_char')
```

Exactly two `cc` errors. `probe(a)` and `probe(b)` differ only in the variable's
name.
