# Patch 24.2h — S1.9 Prerequisite Closure and Stdlib Handoff

**Stdlib S1.9 is unblocked.** It was blocked by two independent causes. Both are closed, and
each was re-derived on exact current main rather than cited from the patch that fixed it.

## Merged publications

| patch | PR | exact head | merge main | exact-head `pull_request` workflows |
| --- | --- | --- | --- | --- |
| 24.2f | #324 | `462a6325b92a64ee4b5adc2d390a641ec9dcb44b` | `6d8a89d8d23327c14f1cc4daa4c0cc582d8a7a63` | 137/137 |
| seed identity authority | #326 | `5403c9aec48fe2409486e101ce9fdd4b36a2df3c` | `d633d83d6d987fe1215f722569c4ff5fcd9d0fee` | 108/108 |
| 24.2g seed publication | #327 | `da7526be64aaedabcd917d05f0c7b989daa69fe1` | `38c794ec804f00c5ba2477b8212f56505bf7d94f` | 35/35 |
| seed transition closure | #328 | `85608085eb2ef4813ff7af9ef0afd488cb8dd7e1` | `9bc80d1392005c05d66de5e28ae0e24d049d2f36` | 108/108 |
| 24.2i roadmap evolution | #329 | `9fc43e5faa` | `10f4479219cc4274c5802b9a02c8714aac175b8c` | 108/108 |

Every population counted at the full 40-character head SHA filtered to `event == "pull_request"`,
with zero unfinished, zero non-success, and zero unresolved non-outdated review threads.

## Blocker 1 — the semantic gap

`mut copied := owner` transferred cleanup ownership but left the source binding usable, so two
names could authorise protected access for one acquisition. Closed by Patch 24.2f.

Re-derived on exact current main. Source reuse is rejected **before backend selection**, with a
byte-identical diagnostic on every route:

```
--backend mir-to-c    exit 1  Semantic Error: LinearResourceUseAfterMove:
                              resource 'source' cannot be used after move
--backend cranelift   exit 1  (identical)
(default)             exit 1  (identical)
```

The valid single-owner transfer compiles on all three routes, and the non-resource control is
unaffected — the rule is driven by resolved Resource metadata, not by syntax, and recognises no
library type, filename, or backend.

## Blocker 2 — the frozen Stdlib roadmap

The CR-15 Stdlib guard byte-pinned four documents this lane must edit, so a single ticked
checkbox failed it. Closed by Patch 24.2i.

Verified on exact current main: ticking the S1.9 box passes, and a change of S1.9's own shape — a
`justfile` guard recipe, the ticked checkbox, and ten new Stdlib-owned paths — also passes.

It remains a real test. Reverting an S1.8 DONE row, removing an S1.8 guard recipe, gutting the
`MutexGuard` blocker section, or deleting finding F6 each still fail.

## Bootstrap

`make bootstrap` reached a byte-identical stage-2/stage-3 fixed point. The published seed
`3f898b4bf34172fb0be90c5a78e8d07b8e319c74bee7a383d2f176267d09bf58` (65784 lines) is the sole
registered identity; the superseded `706430d0…` is rejected by name. The delta is wholly
attributable to Patch 24.2f, so no drift backlog was carried.

## Handoff

The Stdlib lane may resume **S1.9** from exact current main. Its preserved witness matrix was
never entered or modified by the Cranelift lane.

**Patch 24.3 remains paused until Stdlib S1.12.**

## Known deferred work

Marking the Patch 24.2f–24.2h status rows `DONE` in `TASK.md` is **not** included here.
`TASK.md` is byte-pinned by the same class of guard that Patch 24.2i lifted for
`TASK_STDLIB.md`, so the Cranelift roadmap cannot tick its own boxes. That is a real defect,
symmetric to the one 24.2i fixed, and it needs its own enumeration — at least three separate pin
layers are involved. It is deferred to a follow-up patch rather than bundled into this handoff,
because a partly-understood relaxation of a guard family is exactly what the inversion discipline
exists to prevent.
