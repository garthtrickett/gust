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

### Measured result: −5.2%, roughly half the estimate

Merged as `52fbcf2b`. First post-cache data point is PR #44 (Phase 17.6).

**Do not compare raw aggregate runner time between PRs.** The first attempt at
this measurement did, and reported "+267 min, 83% worse" — nonsense. PR #44 runs
187 checks against PR #41's 138 because it touches more path-filtered surfaces
(new workflow, new crate directory, shared authority module). That comparison
measures the job count, not the cache.

The valid method is like-for-like on jobs present in **both** PRs, restricted to
substantial ones (≥60 s), taking the `min` of repeated samples to reduce noise:

| | Total over 61 shared substantial jobs |
| --- | --- |
| Pre-cache (PR #41) | 284m24s |
| Post-cache (PR #44) | 269m42s |
| **Delta** | **−15m42s (−5.2%)** |

Real cache hits, concentrated in the heavy migration guards:

| Job | Change |
| --- | --- |
| `Phase 11 family / pointer-memory` | −147 s |
| `guard (migration-local-binding)` | −102 s |
| `guard / migration-provenance` | −100 s |
| `guard / migration-return-int` | −84 s |

But regressions appear too — `guard / routed-return-int` **+116 s**, and
`migration-return-int` shows **−84 s in one shard and +53 s in another**. Same
job, both directions: that is runner variance, not a systematic effect.

**Honest read:** the estimate was ~9% (~30 min); the measurement is −5.2%. The
cache is doing something — the −100 s-class improvements are too large and too
concentrated to be chance — but this is not the clean win "pure win" implied.
One PR pair with this much variance is not conclusive; get a second data point.

### Second data point, and the noise floor

| Comparison | Shared substantial jobs | Result |
| --- | --- | --- |
| Baseline #41 → #44 (first cached) | 61 | 284m → 269m (**−5.2%**) |
| Baseline #41 → #45 (second cached) | 61 | 284m → 276m (**−2.8%**) |
| #44 → #45 (both cached) | 58 | 269m → 276m (**+2.4%**) |

That third row is the important one. Two PRs that are **both** cached differ by
**+2.4%** from each other. That is the run-to-run noise floor, and it is the same
order of magnitude as the measured effect.

**Conclusion: Lever 1 delivers roughly −3% to −5%, and the measurement cannot
resolve it much more precisely than that.** The estimate was ~9% (~30 min). The
individual −100 s-class improvements in the heavy migration guards are real and
too concentrated to be chance, but at the aggregate level the win is small and
partly buried in variance.

Keep the cache — it costs nothing and it does help. But do not credit it with
more than a few percent, and use the +2.4% noise floor when judging any future
CI change: **anything under ~5% aggregate is not distinguishable from noise on a
single PR pair.**

### Implications for Lever 2

Lever 1 was estimated at ~9% and delivered ~3–5%, roughly a third to a half of
estimate. Applying the same discount to Lever 2's ~77 min (24%) suggests a real
win nearer **8–12%** — larger than Lever 1, but far from the headline figure.

Weigh that against what Lever 2 actually risks: a parity guard silently
validating a stale compiler. That converts a loud failure into a quiet false
pass, in the suite whose entire job is catching backend divergence.

**Recommendation: do not do Lever 2 yet.** The measured evidence says the prize
is smaller than modelled and the noise floor is high enough that success would be
hard to even confirm. Phase 17 capability work is worth more per unit of risk.
Revisit only if CI wall-clock becomes an actual blocker, and if so consider
Lever 3 first — it attacks fixed overhead, carries no staleness class, and is
worth a comparable amount.

### Notes

- 2026-08-16 — implemented; all workflow files parse, `guard-pr-fast-ci-surface`
  and registry projection guards pass unchanged.
- 2026-08-16 — measured −5.2% like-for-like; method and caveats above.

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
| 2026-08-16 | Lever 1 merged (`52fbcf2b`); like-for-like on 61 shared jobs (PR #44) | 284m → 269m (−5.2%) |
| 2026-08-16 | Second data point (PR #45) | 284m → 276m (−2.8%) |
| 2026-08-16 | Noise floor established: two cached PRs differ by +2.4% | — |

## Incident log

**2026-08-19 — apt removed from the guard path.** Three of the four
infrastructure failures observed during a single documentation-only pull request
(#64) were `Failed to install native dependencies after 3 attempts`, the same
signature as the 2026-08-18 mirror incident below and after that incident's
hardening had landed. Retries, timeouts, and `dpkg-query` verification bound the
damage; they do not remove the dependency.

Checking `actions/runner-images` showed the Ubuntu 24.04 image already ships
`curl`, `binutils`, `gcc`, `g++`, `clang`, `make`, `pkg-config`, and `python3`.
Of everything this repository asks apt for, only **ripgrep** is genuinely
missing. The repository was running `apt-get update` — the slow, mirror-dependent
step — to obtain one static binary.

`scripts/install-native-deps-ci.sh` now satisfies each request from what is
already present, installs ripgrep from a pinned release like
`install-just-ci.sh` already does for just, and reaches apt only for whatever
genuinely remains. On a healthy image it makes no apt call. On a changed image it
behaves as before.

Capabilities are probed rather than assumed. `build-essential` is a metapackage
that can be absent while every tool it installs is present, so asking dpkg about
it answers the wrong question; the script compiles a C file instead. This was not
theoretical: in a sandbox lacking `as` and `ld` the probe correctly reported
`build-essential` unsatisfied, and in one with them it correctly reported it
satisfied. A package-name check would have been wrong both times.

**Sizing, corrected.** An initial estimate put this step at ~41% of monthly
runner minutes, extrapolated from a single 104 s observation in PR Fast's build
job. Sampling 103 install steps across four workflows gave a mean of **9 s**
(apt steps ~15 s, max 129 s), so the real figure is nearer **6%** — about 4,400
of 74,000 minutes. The change is worth making for reliability, not for speed:
the flake costs a failed job plus a full re-run, and it is the only recurring
infrastructure failure in this log.

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

**2026-08-18 — degraded Ubuntu mirror wedged runner slots for hours.** PR #54
lost twelve Level 2 parity jobs across Phases 15, 16, and 17 to the same step:
`sudo apt-get update && sudo apt-get install -y ...`. Each hung 20–30 minutes
until its `timeout-minutes` killed it, and each needed a manual requeue. Two
workflows with no timeout at all — `phase15-resource-cfg` and
`phase15-resource-composition` — held the only two active runner slots for
roughly 90 minutes apiece, starving everything queued behind them.

The step runs before any repository code executes and takes no input from the
branch, so the trigger was upstream: GitHub reported Actions "operational"
because the Actions service *was* fine; it was the distro mirror the runners
pull from. What was ours is that the step had no retry, no per-attempt timeout,
and no verification.

Two diagnostic traps worth remembering:

- *A run reporting `queued` is not stalled.* Run-level status shows `queued`
  while its matrix jobs are still dispatching, even as they complete. I read
  two long-`queued` runs as evidence GitHub had stopped scheduling; both were
  progressing normally at 9 jobs done / 12 pending.
- *"The Level 1 job in the same run passed" proves nothing about the runner.*
  Level 1 contract jobs don't install native dependencies at all — they finish
  in ~7 seconds. Only Level 2 parity jobs run apt, which is exactly why only
  they hung. I cited this as evidence several times before checking it.

Fix (`13564188`): `scripts/install-native-deps-ci.sh`, modeled on the existing
retrying installer for `just` — bounded attempts with backoff, a `timeout`
around each apt invocation, `Acquire::*::Timeout` bounding connections inside
apt, and a `dpkg-query` check proving packages are present rather than trusting
exit status. All 44 apt steps across 38 workflows now call it, collapsing six
divergent textual forms into one. Every job carries `timeout-minutes` (was 57
of 90). The Heavy Guards surface guard pins the installer and the hardening
constants, and raw `apt-get` is rejected anywhere under `.github/workflows`.

Result: the rerun went 203/203 with zero apt cancellations. Worst case per job
is now ~10.5 minutes and self-healing; measured healthy path is 10 seconds.

**Implication for Lever 3 (job consolidation).** Each job pays its own cold
`apt-get`, so mirror degradation costs scale with job count. Consolidation now
looks more valuable for *reliability* than for the wall-clock saving it was
originally scoped for.
