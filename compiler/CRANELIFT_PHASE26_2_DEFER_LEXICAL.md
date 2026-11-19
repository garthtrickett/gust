# Deferred lexical storage bindings

This prerequisite repairs native lookup for existing deferred expressions. It
does not close Phase26.2 or qualify deferred allocator teardown ordering.

The merged59 baseline prints inner22 instead of outer11 when an outer defer
executes during an inner return. Fallthrough prints11 and a later assignment to
the original binding prints33. These original failures remain retained outside
the repository; no unsafe resource witness was executed.

`ScheduleDefer` now stores the expression and the visible local storage bindings,
with nearer declarations overriding outer names. `Local` stores a `Place`, so
this captures declaration identity rather than values. Later assignment to the
same storage is still observed. Lowering each deferred expression temporarily
uses its captured bindings and restores the active scope stack before handling
success or failure. Match payload scopes do not need a matching defer frame.

The existing defer stack, LIFO order, loop unwind depths, explicit-versus-
automatic cleanup sequence, canonical operations, ABI and resource/move rules
are unchanged. Deferred allocator validation remains a separate held patch.

The owning allocator identity recipe additionally runs
`python3 scripts/phase26_2_defer_lexical.py validate`, `inversions`, and `native`.
Nine source controls cover fallthrough, early return, late assignment, later
declarations, nested LIFO, break, continue, a late vector write and match-payload
shadowing. The match fixture initializes its local enum before its bounded raw
payload access; all same-named bindings in that control are live `&int`
references, so the old wrong lookup also cannot manufacture an integer pointer.
No resource owner or dangling reference is used. Canonical case
bytes and expected outputs are pinned; changing the oracle or dropping coverage
must refuse. The owning workflow retains these native artifacts separately.

The exact predecessor worker is retained in `predecessor-worker-and-global-census-v3.json.gz` and
checked before projecting its old pins. The new compiler invocation is
enrolled exactly and removed only at the complete global census entry. The
original R3 helper still accepts its own partial row set unchanged. Missing,
extra and substituted calls refuse; foreign calls remain visible. Existing foreign registry authority and
all protected product limits remain intact. Current-source committed reviews,
bootstrap/native/fixed-point/strict104/public/production qualification, complete
pin enumeration, owning CI artifacts and checked merge gate acceptance.

The first corrected-fixture cold build exposed an owned-disk sampler race:
GNUdu returned an error when the compiler removed temporary request and bundle
children during traversal. The controller stopped that run before native cases;
the failed evidence remains unqualified. The sampler now allows at most three
complete scans for exact missing-child diagnostics within checked owned roots.
It discards failed partial totals and retains diagnostics. Root disappearance,
symlink escape, foreign or unknown errors, and retry exhaustion still refuse.
Growth, reserve, memory and deadline assertions are unchanged. The owning recipe
runs the execution controls, including real deletion recovery and these refusals.
Exact merged59 sampler/control bytes are retained in
`owned-disk-scan-predecessor-v1.json.gz`; rollback and source-pin substitutions
remain rejected before fresh cold-build and downstream qualification.
