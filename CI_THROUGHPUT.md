# CI Throughput

Working notes for reducing GitHub Actions cost on this repository. Each lever is
its own PR: infrastructure changes stay out of capability patches, because a
guard that goes green after a caching change should never leave you wondering
whether the code is right or the caching altered what was tested.

See **Ordered plan** below for current status. The levers divide into two kinds,
and the distinction is the whole game — see **The concurrency ceiling**.

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

## The concurrency ceiling

Levers 1–3 all reduce **per-job duration**. The binding constraint is a
**concurrency** limit: 20 jobs at once on the Free plan, [per billing
entity](https://docs.github.com/en/actions/reference/limits), the same for public
and private repositories. With `N` jobs and 20 slots you wait `ceil(N/20)` waves
however fast each job runs. Caching shortens waves; it does not remove them.

So the levers split in two:

| Kind | Effect | Levers |
| --- | --- | --- |
| Reduce per-job duration | shorter waves | 1, 2, 3 |
| Reduce job count, or raise the cap | **fewer waves** | 4, 5, 6 |

Both matter, but only the second kind moves the ceiling. Measured 2026-08-19 on
PR #64, a documentation-only change:

| | jobs | aggregate |
| --- | --- | --- |
| Heavy Guards | 41 | 120 min |
| PR Fast | 22 | 133 min |
| 21 phase workflows (2 jobs each) | 42 | — |
| **per push** | **~169** | ~9 waves |

The wave count matches the original baseline's "roughly nine sequential waves".

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

**Status:** merged 2026-08-16 (`52fbcf2b`, PR #43). 41 workflows carry a cache
step. This heading read "not started" until 2026-08-19 while the Changelog below
already recorded the merge — the status line was simply never updated.
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

**Status:** already implemented, discovered 2026-08-19. Not by this document's
plan — by whoever added `Upload Gust build outputs` to `pr-fast.yml`.

Both large workflows already build `gust` once and share it:

```
Heavy Guards / migration-if-else:   1s  actions/download-artifact@v4  →  702s guard
PR Fast     / migration-provenance: 5s  Download Gust build outputs   →  683s shard
```

The "23 jobs doing a full bootstrap" this lever targeted were those shards. They
stopped bootstrapping some time ago; the estimate of ~77 min was measured before
that happened and was never revisited.

**Remaining scope, and it is small.** The ~35 phase-workflow parity jobs still
bootstrap. Their *entire* guard step is 80 s — `make gust` is ~126 s locally but
much less on a runner with the Lever 1 cache warm. Extending the artifact to them
is worth roughly 20–30 min of aggregate runner time and **nothing** in
wall-clock: they finish at ~100 s while the critical path is ~12 min. Do it for
cost, not for speed, and only after the levers below.

**Risk:** medium — this is a correctness change wearing a performance costume
**Original target:** the 23 jobs doing a full bootstrap

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

## Lever 3 — Job splitting (was: consolidation)

**Status:** merged 2026-08-19
**Prize:** PR Fast critical path ~23 min → ~12.5 min

This lever was scoped as *consolidation*: fold the ~86 sub-two-minute jobs into
fewer matrix entries to reduce job count. That was right at 20 concurrent slots.
At 40 it is backwards. Short jobs are nearly free; consolidating them *lengthens*
the critical path, because a wave costs as much as its slowest member. The
correct move is the opposite.

Measured on PR Fast, 2026-08-19 (wall-clock 03:15:23 → 03:53:31, 38 min):

| | |
| --- | --- |
| `build and Level 1 contracts` — everything `needs:` it | **688 s** |
| ↳ `Build Gust` | 126 s |
| ↳ 52 Level 1 guards, **sequential in that one job** | 431 s |
| ↳ `Install guard tools` | 104 s |
| then the longest shard, `migration-provenance` | **710 s** |

Critical path ≈ 688 + 710 ≈ 23 min. Three changes:

**3a — split the build job. Attempted, reverted, deferred.** The plan was to
reduce `build` to checkout, install, `make gust`, and upload, moving the 52
Level 1 contracts into a `level1` matrix of 3 duration-balanced shards. Serial
prefix **688 s → ~255 s**, the largest single win available.

It does not fit in this pull request. **Fourteen scripts read `pr-fast.yml`**, and
twelve of them assert that a specific guard is invoked there — for example
`phase17_close.py:212` requires `run: just guard-cranelift-phase17-close` to
appear exactly once. Guards living in a dispatcher recipe satisfy none of those
assertions. A merge simulation against `main` caught all twelve failing; the
first implementation had updated only `cranelift_test_levels.py` and
`guard-pr-fast-ci-surface`.

The twelve use three different idioms, and one is a data-driven loop over
`(path, token)` pairs requiring the literal `run: just <guard>` string in the
workflow file. That contract cannot be satisfied while the guards live in a
recipe; it has to be renegotiated deliberately, across all fourteen scripts, as
its own change.

So 3a is deferred rather than bundled. The prize is unchanged and it remains the
largest single item in the plan.

**3b — split the migration shards.** Each ran exactly two guards, an
`owned-*-validation` and a `feature-*-routed-execution`, for ~690 s. Heavy Guards
now runs them as 8 single-guard shards of ~345 s. Longest shard **727 s → ~345 s**.

**3c — stop running the migration shards twice.** All four were byte-identical
between `pr-fast.yml` and `heavy-guards.yml` — same two guards each, verified in
both justfile dispatchers. They were also the four slowest jobs in both, ~46 min
of exactly duplicated compute per push. They now run in Heavy Guards only, which
also owns `migration-surfaces` and is the deep-verification path. No PR loses
coverage: Heavy Guards runs on `pull_request` too.

### Guard contracts were updated, not worked around

Moving 52 guards out of the workflow would have silently voided the checks that
keep this architecture honest — `check_pr_workflow` counts guard invocations in
the workflow text, and `require_direct_levels` verifies every directly-invoked
guard is Level 1 or 2. Guards inside a dispatcher recipe are invisible to both.

So the checks were extended to span the recipe as well as the workflow:
`scripts/cranelift_test_levels.py` gained `just_recipe_body()`, and
`guard-pr-fast-ci-surface` now searches workflow-plus-recipe. Sharding still
cannot drop a contract or smuggle in a guard from another level.

Verified by set comparison before and after: PR Fast's guard set lost exactly the
7 migration guards intended by 3c and nothing else, and all 7 are present in the
Heavy Guards dispatcher. Every one of the 50 guard scripts that passes on `main`
still passes here.

## Lever 3 (original) — Job consolidation

**Status:** superseded by Lever 3 above. Retained for the reasoning.
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

## Lever 4 — duplicate-run elimination

**Status:** merged 2026-08-19 (this document's PR)
**Risk:** low — no coverage is lost for any pull request
**Prize:** −63 jobs and −253 min per push, roughly **37% of the job count**

`pr-fast.yml` and `heavy-guards.yml` triggered on `push: branches: [main, codex/**]`
**and** on `pull_request`. Because agents publish to `codex/**` and open a pull
request immediately, every push fired both events and ran both workflows twice.
Confirmed on all five commits of PR #64: two `Heavy Guards` runs and two
`PR Fast` runs per SHA, every time.

The 49 phase workflows were never affected — their `push:` is scoped to `main`
alone. Only the two largest workflows had the wider scope.

The fix is to drop `codex/**` from those two `push:` triggers. Pull requests keep
full coverage through the `pull_request` event. Three things make this safe:

- the required `Codex / Trusted actor` check comes from `codex-trusted-ci.yml`,
  a separate push-only workflow that is untouched;
- `workflow_dispatch` still reaches both workflows on any branch, and the
  in-workflow `if:` conditions already handle that event, so manual runs on a
  `codex/**` branch still work;
- `AGENTS.md` requires opening a draft pull request immediately, so a `codex/**`
  branch without a PR is not a state the workflow is expected to cover.

Verified: `guard-pr-fast-ci-surface` and `guard-cloud-heavy-ci-surface` both
pass, and no guard, script, or workflow asserts anything about trigger branch
lists.

## Lever 5 — concurrency groups

**Status:** merged 2026-08-19 (this document's PR)
**Risk:** low
**Prize:** superseded runs stop holding slots the moment a new commit lands

Exactly one workflow of 53 declared a `concurrency:` block. Everything else let
superseded runs occupy slots until they finished on their own. On PR #64, five
pushes meant runs for four dead SHAs competing with the live one for the same 20
slots.

The `AGENTS.md` Runner Policy exists to compensate: it tells the agent to run a
`gh run cancel` script filtered to non-current-`HEAD` runs on the branch. That
policy is a manual reimplementation of a platform feature. Both now exist; the
platform handles the common case and the script remains as a backstop for
anything it misses.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

`head_ref || ref` keys pull requests by source branch and pushes by ref, so the
two event types land in the same group for the same branch. Cancellation is
disabled on `main` — a push to `main` is a merge, and cancelling it would leave
the merge commit unverified.

### Pending runs are cancelled even with `cancel-in-progress: false`

Observed 2026-08-19 while merging four pull requests in quick succession: 22
runs on `main` showed `cancelled` despite the expression above evaluating to
`false` there. This is not a misconfiguration and it is worth writing down,
because it reads exactly like one.

GitHub protects the **in-progress** run in a concurrency group. It does not
protect **pending** ones: when a newer run joins the group, previously pending
runs in it are cancelled regardless of `cancel-in-progress`. With a deep queue,
four merges in a row therefore leave one pending run per group — the newest —
and cancel the rest.

The effect is desirable: `main` gets validated at its tip rather than at three
intermediate states nobody will ship. But it changes what "main is green" means.
It refers to the tip only, and intermediate merge commits may carry no evidence
at all. When bisecting a failure across a burst of merges, do not read a
`cancelled` run as a signal about that commit — there is simply no result for it.

Two ways to get per-commit evidence when it matters: merge one pull request at a
time and let its runs finish, or re-run the workflow against the specific commit
afterwards.

### Deliberate exclusions

Three workflows are deliberately excluded:

- `codex-trusted-ci.yml` — already had its own group.
- `cranelift-historical-full.yml` — the sole Level 3 owner, scheduled nightly.
  Adding cancellation semantics to the authoritative historical suite is a policy
  change deserving its own review, the same reasoning that keeps it out of the
  cache lever.
- `blacksmith-smoke.yml` — a single-job manual smoke test.

## Lever 6 — raise the concurrency ceiling

**Status:** not started

Levers 4 and 5 cut the job count. This one raises the cap. Verified 2026-08-19:

| Option | Concurrent jobs | Cost | Note |
| --- | --- | --- | --- |
| Free (current) | 20 | — | per billing entity, not per repository |
| Ask GitHub Support | negotiable | free | the limits page states support can raise it |
| **GitHub Pro** | **40** | ~$4/mo | straight 2× |
| Team | 60 | $4/user/mo | |
| Blacksmith | separate pool | 3000 free min/mo, then ~½ GitHub | `blacksmith-smoke.yml` is an unfinished evaluation |
| Ubicloud | separate pool | ~$0.0008/min | open source, cheapest observed |
| Self-hosted | your hardware | free | GitHub advises against on public repositories; the `CODEX_GITHUB_ACTOR` gate mitigates but does not erase this, and the machine would contend with local agent work |
| ~~BuildJet~~ | — | — | **shutting down 2026-03-31 — do not adopt** |

With Lever 4 landed, roughly 105 jobs per push. At 20 slots that is ~6 waves; at
40 it is ~3. Combined with Levers 2 and 3 shortening each wave, the compounding
is worth more than any single item here.

## Ordered plan

- [x] **Lever 1 — Rust cache.** Merged `52fbcf2b` (PR #43), 41 workflows.
- [x] **Lever 4 — duplicate-run elimination.** −37% job count.
- [x] **Lever 5 — concurrency groups.** 50 workflows, 3 deliberate exclusions.
- [ ] **Lever 6a — GitHub Pro.** 20 → 40 concurrent jobs. Account-level purchase;
      no repository change required. Re-measure wave count afterwards.
- [x] **Lever 6a — GitHub Pro.** 20 → 40 concurrent jobs.
- [x] **Lever 2 — Gust binary artifact.** Found already implemented for the two
      large workflows. Remainder is the ~35 phase parity jobs: ~20–30 min
      aggregate, zero wall-clock. Deferred as a cost item.
- [x] **Lever 3b/3c — split the migration shards, stop running them twice.**
      Heavy Guards longest shard 727 s → ~345 s; ~46 min/push of duplication gone.
- [ ] **Lever 3a — split PR Fast's build job.** Serial prefix 688 s → ~255 s, the
      largest single remaining win. Blocked on renegotiating the `pr-fast.yml`
      guard-invocation contract across the 14 scripts that read it.
- [ ] **Cut `Install guard tools` (104 s per job).** Now the largest fixed
      overhead, paid by every one of ~105 jobs. It is an `apt-get` install, which
      is also the source of every flake in the incident log. Cache the packages,
      or move to a runner image that ships them.
- [ ] **Shard `phase11-family`.** With 3a and 3c landed, `phase11-family /
      pointer-memory` at 502 s is the new critical path in PR Fast.
- [ ] **Re-measure and update the Changelog.** The estimates above are derived
      from the 2026-08-16 baseline and the 2026-08-19 job census, not from a
      post-change measurement.
- [ ] **Lever 6b — third-party runners**, only if 6a plus Levers 2 and 3 prove
      insufficient. Finish or delete `blacksmith-smoke.yml` rather than leaving
      an unfinished evaluation in the tree.

## Changelog

| Date | Change | Aggregate runner time |
| --- | --- | --- |
| 2026-08-16 | Baseline measured on PR #41 | 320 min |
| 2026-08-16 | Lever 1 merged (`52fbcf2b`); like-for-like on 61 shared jobs (PR #44) | 284m → 269m (−5.2%) |
| 2026-08-16 | Second data point (PR #45) | 284m → 276m (−2.8%) |
| 2026-08-16 | Noise floor established: two cached PRs differ by +2.4% | — |
| 2026-08-19 | Job census on PR #64: ~169 jobs/push, ~9 waves | — |
| 2026-08-19 | Levers 4 and 5 merged; job count −37%, superseded runs auto-cancelled | pending re-measure |
| 2026-08-19 | Lever 2 found already implemented; estimate was pre-artifact | — |
| 2026-08-19 | Lever 3 re-scoped from consolidation to splitting, and merged | pending re-measure |

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
