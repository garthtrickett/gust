# CI Throughput

Working notes for reducing GitHub Actions cost on this repository. Three levers,
ordered by safety × impact. Each lever is its own PR: infrastructure changes stay
out of Phase 17 capability patches, because a guard that goes green after a
caching change should never leave you wondering whether the code is right or the
caching altered what was tested.

## Baseline measurement

Measured on PR #41 (`codex/phase17-5-runtime-import`, Phase 17.5), 2026-08-16.
Reproduce with `gh pr checks <n>` and sum the duration column.

| Metric | Value |
| --- | --- |
| Completed checks per PR | 138 |
| **Aggregate runner time** | **320 min** |
| Jobs ≥ 2 min | 53 jobs — **280 min (85% of wall-clock)** |
| Jobs < 2 min | 86 jobs — 50 min (15%) |
| Mean check duration | 139 s |
| Scripts running **both** Gust bootstrap and `cargo build` | 23 |
| Scripts running `cargo build` | 46 |
| Workflows with any caching or artifact reuse | **2 of 40** |
| Cranelift `target/` size | 706 MB, rebuilt cold per job |

Slowest jobs observed:

| Job | Duration |
| --- | --- |
| `guard (migration-if-else)` | 733 s |
| `guard (migration-provenance)` | 724 s |
| `guard (migration-local-binding)` | 688 s |
| `build and Level 1 contracts` | 659 s |
| `guard (migration-return-int)` | 509 s |
| `guard (mir-branch)` | 471 s |

Runner facts: `gust` is a **public** repository, so GitHub-hosted `ubuntu-latest`
runners are 4 vCPU / 16 GB RAM / 14 GB SSD (private repos get 2 vCPU / 7 GB), and
Actions minutes are unbilled. The cost is wall-clock and the concurrency cap
(20 concurrent Linux jobs on Free), not money. ~180 checks against 20 slots is
roughly nine sequential waves regardless of per-runner speed.

> Runner specs above are from GitHub's documented tiers, not measured on these
> runners. To confirm empirically, add `nproc && free -g` to a diagnostic step.

## Measured build costs

Timed locally 2026-08-16 (4 vCPU class machine, comparable to a public-repo runner):

| Operation | Cold | Warm | Notes |
| --- | --- | --- | --- |
| `cargo build` (cranelift worker, 48 deps) | **62 s** | 0.04 s | 527 MB target dir |
| `make gust` (full bootstrap) | **202 s** | n/a — always forced | see constraint below |

A parity job therefore spends roughly **264 s building** before its assertion,
which itself takes milliseconds.

### Prize per lever, from these numbers

| Lever | Scope | Estimated saving | Share of 320 min |
| --- | --- | --- | --- |
| 2 — Gust binary artifact | 23 jobs × 202 s | **~77 min** | **24%** |
| 3 — Job consolidation | 86 jobs × ~25 s | ~36 min | 11% |
| 1 — Rust cache | 29 jobs × 62 s | ~30 min | 9% |

**This inverts the original ordering-by-value.** The first draft of this document
assumed Lever 1 carried the larger practical win and that Lever 2's remaining
prize would shrink once Lever 1 landed. The measurements say the opposite: the
bootstrap is 3.3× more expensive than the cargo build, so Lever 2 is worth about
2.5× Lever 1. Levers 1 and 3 are close to each other in value.

Ordering by *risk* is unchanged (1 → 3 → 2). Lever 1 still goes first, but for
risk-management reasons and to establish the measurement harness — not because
it is the biggest win. Do not skip Lever 2 on the assumption it is marginal.

### Lever 1 is less mechanical than first described

**22 of the cargo scripts override `CARGO_TARGET_DIR`** to a per-guard directory:

```bash
cargo_target="$build_root/cargo-target"   # build/guards/<guard>/cargo-target
```

A stock `Swatinem/rust-cache` keyed on the default workspace target dir gives
those 22 jobs **zero benefit** — it would cache
`compiler/experiments/cranelift/target/`, which they never write to. Each needs
its target dir named explicitly (`workspaces: <path> -> <target-dir>`) or a
plain `actions/cache` over `build/guards/*/cargo-target`.

This does not create a staleness class — cargo's fingerprinting is sound, and a
restored cache is per-job, so the deliberate cross-guard isolation is preserved.
But "drop one action into 29 workflows" was wrong; it is 22 bespoke target-dir
configurations plus 7 straightforward ones.

## The correctness constraint

`scripts/run-gust-file.sh:17` deliberately forces a full rebuild:

```bash
# Force make to recognize compiler changes by touching the entrypoint and rebuilding.
touch compiler/test_runner_entry.gst
```

This is intentional: someone already decided a stale compiler is worse than a
slow build. **Any plan that shares the `gust` binary must not defeat this by
accident.** A parity guard that silently validates yesterday's compiler is worse
than a slow one — it converts a loud failure into a quiet false pass.

The nuance that makes Lever 2 possible: the forced rebuild protects against
*local incremental staleness on a developer machine*, not against *cross-job
staleness on a pinned CI SHA*. Those are different threats.

---

## Lever 1 — Rust cache

**Status:** not started
**Risk:** low — no staleness class to reason about
**Target:** the 46 jobs running `cargo build`

Add `Swatinem/rust-cache` so the 706 MB Cranelift `target/` is not rebuilt cold
in every parity job. Cargo's dependency tracking is sound, so unlike Lever 2 this
introduces no correctness surface — it is a pure win and mechanical to review.

Do this one first and **measure before deciding on Lever 2**: with Lever 1
landed, the remaining win from binary sharing may be materially smaller than the
baseline above suggests.

### Implementation

One **uniform** `actions/cache@v4` step added to the 28 workflows whose jobs
transitively reach cargo, inserted only into the specific jobs that do. The 11
workflows that never reach cargo were left untouched.

The "22 bespoke configs" problem dissolved on inspection: all 22 custom target
dirs live under `build/guards/<guard>/cargo-target`, so a single glob covers
them alongside the default dir.

```yaml
path: |
  ~/.cargo/registry/index
  ~/.cargo/registry/cache
  ~/.cargo/git/db
  compiler/experiments/cranelift/target
  build/guards/*/cargo-target
key: cargo-${{ runner.os }}-${{ github.workflow }}-${{ hashFiles('.../Cargo.lock') }}
```

**Hazard avoided — do not "simplify" this to `build/guards`.** Those directories
also hold guard witnesses, mutation request files, and the `.output` sentinels
that parity guards use to prove no output was replaced before a rejection.
Restoring stale copies of those could manufacture a false pass. Cache
`build/guards/*/cargo-target` and nothing else.

`Swatinem/rust-cache` was considered and rejected: it is opinionated about
workspace target dirs, which does not fit the two-regime layout here. Its one
real advantage is pruning to dependency artifacts, which keeps caches small —
see the size risk below.

### Excluded by existing policy: `heavy-guards.yml`

`guard-cloud-heavy-ci-surface` (justfile:652) asserts:

```
Cloud heavy guard workflow must not enable cache yet.
```

The first attempt at this lever added a cache step to `heavy-guards.yml` and CI
rejected it. **The guard is correct and the exclusion stands.** Heavy Guards is
the deep-verification path; keeping it hermetic means it cannot pass on restored
state. That is the same reasoning as the forced rebuild in `run-gust-file.sh` —
the authoritative verification path must not be able to go green on stale
artifacts.

So the cache covers **28 workflows, not 29**. If Heavy Guards is ever to be
cached, that is a deliberate policy change with its own review, made by editing
the guard first — not by quietly adding a cache step and finding the guard in
the way.

Only `heavy-guards.yml` carries this policy; `cranelift-historical-full.yml` and
the rest have no equivalent assertion.

### Open risk: cache size

GitHub allows 10 GB of Actions cache per repo with LRU eviction. Cold target dir
measured at **527 MB**. Keyed per workflow, 29 caches could approach or exceed
the limit and thrash. Watch the hit rate on the first few runs. If eviction is
observed, options are (a) a shared key across workflows, accepting that only the
`~/.cargo` portion helps universally, or (b) `Swatinem/rust-cache` per workflow
with an explicit target-dir mapping, for its pruning.

### Notes

- 2026-08-16 — implemented; all 40 workflow files parse, `guard-pr-fast-ci-surface`
  and registry projection guards pass unchanged.
- (record measured before/after aggregate runner time here once merged)

---

## Lever 2 — Gust binary artifact

**Status:** not started
**Risk:** medium — this is a correctness change wearing a performance costume
**Target:** the 23 jobs doing a full bootstrap

Build `gust` once, share it to downstream jobs. `pr-fast.yml` already uploads
`./gust` via `Upload Gust build outputs`, so the pattern exists in the repo; the
standalone phase workflows just don't consume it.

Sound in CI **only** with all of:

1. Artifact keyed to the **exact commit SHA**.
2. Consumer **verifies** it received that SHA before using it.
3. Fallback is **build it yourself**, never "use whatever is present".
4. **Fail-closed, never fail-quiet.**

Review this as a correctness change, not a speed change.

### Notes

- (record design decisions and any staleness incidents here)

---

## Lever 3 — Job consolidation

**Status:** not started
**Risk:** high — most likely to fight existing invariants
**Target:** the 86 sub-2-minute jobs

Many pay 20–30 s of checkout and setup for a 5–7 s assertion. Batching Level 1
contracts into fewer jobs attacks *fixed overhead* rather than build time.

Blocker to respect: this touches the registry-derived CI family projection that
`guard-pr-fast-ci-surface` validates (currently "projected shards=20 within
max=23"). Expect to update the projection and its guard together, and expect the
guard to push back — that is the guard doing its job.

### Notes

- (record projection changes here)

---

## Changelog

| Date | Change | Aggregate runner time |
| --- | --- | --- |
| 2026-08-16 | Baseline measured on PR #41 | 320 min |

## Incident log

**2026-08-16 — cache step split multi-line steps.** The first insertion pass
placed the cache block at `checkout_line + 1`. Where a workflow's next step was
a two-line `- name:` / `run:` pair, that landed *inside* the step: the cache step
inherited a stray `run:` and `Install native dependencies` lost its own. Seven
workflow files were rejected outright by GitHub (the run name shows as the file
path when a workflow fails to load).

`yaml.safe_load` did **not** catch this — the result is valid YAML and only
invalid against the Actions schema. Local validation was checking the wrong
thing.

Fix: insert at the next *step boundary* (`^      - `) after the checkout step,
never at a fixed line offset. Added a schema check that asserts every step has
exactly one of `uses` or `run`; that check fails on the broken form and passes
on the fixed one. Use it, not `yaml.safe_load`, when editing workflows in bulk.
