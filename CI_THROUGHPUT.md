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

**3a — split the build job. Done, on the second design.**

`build` now does checkout, install, `make gust`, and artifact upload. A sibling
`level1` job depends on it and runs the 52 Level 1 contracts, consuming the same
`gust` artifact the other jobs already use. Serial prefix **688 s → ~255 s**;
`level1` runs concurrently with `guard` and `phase11-family` instead of ahead of
them.

The first attempt moved the contracts into a sharded dispatcher recipe and broke
twelve guard scripts, because the problem was misdiagnosed. It is not that the
52 guards share a job — it is that they share the job everything else `needs:`.
Moving them to a *sibling* job fixes the dependency without moving them out of
the workflow file, so every `run: just <guard>` line stays exactly where the
twelve scripts look for it. Four assertions needed updating instead of fourteen
contracts: the `install-just` count, and the `final` job's `needs:` list in
`guard-pr-fast-ci-surface`, `cranelift_test_levels.py`, and
`cranelift_ci_family.py`.

The sharding idea is dropped, not deferred. `level1` at ~535 s sits alongside
`phase11-family` at 502 s, so sharding it would buy nothing until that changes.

The record of the first attempt follows, because the reasoning is what makes the
second design obviously correct.

**3a — first attempt, reverted.** The plan was to
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

## A guard nobody runs is not a saving

`guard-mir-to-c-boring-surface` was in no workflow. Its only caller is
`guard-mir-feature-migration-suite`, which `make test` runs, and `make test` is
in no workflow either. So it failed only for whoever ran the full local suite —
and it took the suite down with it.

It had been failing since roughly Phase 10. Two of its blocks were Phase 8/9
gates asserting Cranelift was still a contained experiment: a hand-maintained
allowlist of Cranelift `justfile` recipes, and a ban on the word `cranelift`
appearing anywhere in `compiler/`, `src/`, or `tests/`. By 2026-08-19 that was
327 recipes against 62 allowlist entries, 249 flagged, last maintained
2026-07-13.

Both blocks are removed. Their intent is carried by things that do run in CI:
`scripts/cranelift_test_levels.py` for Level 1/2/3 ownership, and
`guard-cranelift-dependency-beachhead` for production routing. The rest of the
guard — manifest entry counts, retirement statuses, suite wiring, and four
MIR-to-C native smokes — still runs and still passes.

**The guard is now a Heavy Guards shard**, which is the point. This adds a job in
a document otherwise about removing them, and that is deliberate: the same rot
took down the Level 3 nightly for a month for the same reason, invisibility.

**It does extend the Heavy Guards critical path, and the first estimate of that
was wrong.** Timed locally at **854 s** — each of the guard's four native smokes
forces a full `make gust` rebuild through `scripts/run-gust-file.sh`, whose
`touch` is deliberate and must not be defeated. The current longest Heavy Guards
job is `mir-branch` at 478 s. So this becomes the longest shard and sets Heavy
Guards' wall-clock, roughly 478 s → 600-850 s. CI may be faster than this machine
— `make gust` measured 126 s on a runner against about 200 s locally, and this
timing ran alongside other work — but it will still be the longest.

That is the honest trade: about five minutes of Heavy Guards wall-clock, once per
push, to stop a guard from failing invisibly for nine phases. Taken knowingly. If
it proves too expensive, the fix is to make the four smokes share one build
rather than to remove the shard.

Heavy Guards goes from 37 to 38 shards, within its declared maximum of 40.

## Measured outcome

Taken on `main` at `bc40864` with a quiet queue, against the PR #64 baseline.
Both runs passed.

| | before | after | |
| --- | --- | --- | --- |
| PR Fast — `build` job | 688 s | **128 s** | −81% |
| PR Fast — aggregate | 133 min | **81 min** | −39% |
| PR Fast — longest job | 710 s | **578 s** | now `phase11-family / pointer-memory` |
| PR Fast — jobs | 22 | 19 | |
| Heavy Guards — longest job | 727 s | **490 s** | −33% |
| Heavy Guards — aggregate | 120 min | **108 min** | −10% |
| Heavy Guards — jobs | 41 | 45 | 3b split adds jobs on purpose |

**Critical path, which is what the levers targeted:** `build` + longest dependent
job, 688 + 710 = 1398 s before, 128 + 578 = **706 s** after. That is 23 min → 12
min, against a projection of ~13 min. Lever 3a is the bulk of it: the `build` job
fell from 688 s to 128 s because the 52 Level 1 contracts moved off the serial
prefix.

**Observed wall-clock improved less: 38 min → 29 m 45 s.** The gap is scheduling,
not work. `build` finished at 08:34:26 and the first dependent job started at
08:37:46 — a 3 m 20 s hole with nothing running, and similar gaps recur as the
matrix fills. Roughly half the wall-clock of a PR Fast run is now runners waiting
to be allocated rather than jobs executing.

The cause is the concurrency cap, and an earlier draft of this section got that
wrong. It claimed "raising concurrency does not help — the jobs are not queued
behind our own jobs." They are.

Measured 2026-08-19 by pulling every workflow run overlapping a window,
deduplicating by run ID, and counting each job's `started_at`/`completed_at`,
**including only jobs that concluded `success` or `failure`**:

| Window (UTC) | Jobs executed | Peak concurrent |
| --- | --- | --- |
| 03:00–10:00 | 1,066 | **20** |
| 08:00–10:00 | 452 | **19** |

Concurrency reached exactly 20 and never 21, across seven hours. That is the
Free-plan limit; Pro documents 40. A support ticket is open asking why.

**Counting method matters here, and two earlier figures were wrong.** A first
pass sampled only two runs and reported a peak of 14, ignoring every other
workflow running at the same time. A second pass covered all runs and reported
46 — but counted **cancelled** jobs, which record a `started_at`/`completed_at`
interval without ever occupying a runner. At the claimed 46-job peak, 39 of the
41 jobs were cancelled. Roughly a hundred runs were cancelled by hand that day,
so the error was large. Filter to `success` and `failure` before counting
concurrency.

So the remaining wall-clock is queueing against a cap, not scheduling latency,
and it responds to exactly two things: fewer or shorter jobs, which this document
is about, and a higher cap, which the ticket is about.

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
- [x] **Lever 3a — split PR Fast's build job.** Serial prefix 688 s → ~255 s, via
      a sibling `level1` job rather than a dispatcher recipe, so the
      `pr-fast.yml` guard-invocation contract is untouched.
- [ ] **Cut `Install guard tools` (104 s per job).** Now the largest fixed
      overhead, paid by every one of ~105 jobs. It is an `apt-get` install, which
      is also the source of every flake in the incident log. Cache the packages,
      or move to a runner image that ships them.
- [ ] **Resolve the concurrency cap.** Peak concurrency measures 20, the
      Free-plan limit, on an account that should have Pro's 40. Support ticket
      open. Until it resolves, about half of a PR Fast run's wall-clock is
      queueing against that cap.
- [ ] **Shard `phase11-family`.** `phase11-family / pointer-memory` at 578 s is
      the longest job in PR Fast. Worth less than it looks while allocation gaps
      dominate.
- [ ] **Re-measure and update the Changelog.** The estimates above are derived
      from the 2026-08-16 baseline and the 2026-08-19 job census, not from a
      post-change measurement.
- [ ] **Lever 6b — third-party runners**, only if 6a plus Levers 2 and 3 prove
      insufficient. Finish or delete `blacksmith-smoke.yml` rather than leaving
      an unfinished evaluation in the tree.
- [ ] **Lever 7 — docs-only fast path for `pr-fast.yml`.** `paths-ignore` for
      root Markdown. One YAML key; the guard-script coupling that looked like a
      blocker does not exist. CI/guard lane.
- [ ] **Lever 8 — drop `push: main` outside a sentinel set.** Measured at **20%
      of the queue** (32 of 158 runs; 29 from a single merge, 45 min old and
      unstarted). Re-proves what the PR already proved. Keep `pr-fast` and
      `heavy-guards` as sentinels for close-together merges. CI/guard lane.

## The ten-PR steady state, measured 2026-08-20

Every lever above reasons about a single wave. This section is about what happens
when three lanes have ten pull requests open at once, which is now the normal
condition rather than an unusual one.

### Census at 03:53 UTC

| PR | lane | queued | note |
| --- | --- | --- | --- |
| #99, #96, #111 | Cranelift | ~295 | page-capped, see below |
| **#97, #112, #113** | **Stdlib/CI (mine)** | **58 / 55 / 54** | exact |
| #98 | docs/VISION | 35 | draining fastest |
| #100, #107, #109 | Cranelift | 0 | all checks cancelled by their owner |

Ten open pull requests, **at least 496 queued checks**, against a concurrency cap
that measures 20.

### Drain rate

Computed from the `completed_at` timestamps of successful check runs across all
open pull requests, in a single API sweep. Sampling this by polling would perturb
what it measures and take as long as the thing being measured.

| window | successful checks completed | rate |
| --- | --- | --- |
| last 5 min | 12 | 2.4/min |
| last 10 min | 18 | 1.8/min |
| last 15 min | 24 | 1.6/min |
| last 30 min | 42 | 1.4/min |
| last 60 min | 67 | 1.1/min |

### Both numbers are lower bounds, and the document should say so

**7 of the 10 pull requests returned exactly 100 check runs**, which is the
`per_page` cap on `/commits/{sha}/check-runs`, not a real total. Their true counts
are higher by an unknown amount, so both the 496 and every rate above understate
the load. A throughput document that reports a lower bound as a measurement is
worse than one that reports nothing, because the error is invisible downstream.

**This caveat is not theoretical and it caught the author of this section.** An
un-paginated read of one pull request reported 22 succeeded and 78 outstanding;
paginating the same request at the same moment gave **41 succeeded of 119 total**.
The un-paginated figure was wrong by 19 checks and looked entirely plausible —
exactly 100 is the tell, and it is easy to miss because it is a round number in a
column of round numbers. Anything reporting exactly 100 should be assumed
truncated until paginated. Use `gh api --paginate`.

The three pull requests showing zero queued are excluded from the rate: their
checks were **cancelled** by their owner deliberately clearing the head of the
train. Counting cancellations as drain would inflate the rate — the same error
that once produced a bogus peak-concurrency figure of 46 in the section above.

### Measured concurrency is far below the cap, and it ramps

The obvious explanation for the drain rate is the concurrency cap. It is wrong,
and it is worth stating plainly because this document has previously drawn the
cap conclusion twice.

Counting **jobs** with status `in_progress` across every running workflow, three
consecutive samples:

```
in_progress JOBS=5   queued-inside-running-runs=0   in_progress runs=5
in_progress JOBS=5   queued-inside-running-runs=0   in_progress runs=5
in_progress JOBS=5   queued-inside-running-runs=0   in_progress runs=5
```

Five. Not 20, not Pro's 40, against roughly 500 queued checks. And five
concurrent jobs at two to five minutes each *is* 1–2.5 completions per minute,
which reproduces the drain rate measured above. The two measurements agree.

**But five is not a ceiling.** Sampling the same jobs view every three minutes
for the following twenty-five gives:

```
04:01  5, 5, 5      (three consecutive samples)
04:14  10
04:17   8
04:20   9
04:23  13
04:26  15
```

```
04:29  11   04:32  14   04:35  12   04:38  11
04:41   9   04:44  11   04:47  13
```

Twelve samples over thirty-three minutes: **10, 8, 9, 13, 15, 11, 14, 12, 11, 9,
11, 13.** Mean 11.3, range 8–15, no trend across the second half.

Read at 04:26 this looked like a monotonic climb from 5 to 15. It is not. The
full series resolves into **a ramp from 5 up to a noisy plateau of about 11,
oscillating 8–15** — comfortably below a cap of at least 20. Every running
workflow contributes exactly one job, so this is workflow admission, not
jobs-per-workflow growing.

Two samples suggested a fluctuation, six suggested a climb, twelve show ramp then
plateau. The ramp rule applied to itself: *samples taken close together are one
observation of a level, not evidence of a ceiling.*

The final sample is worth reading closely for a second reason. Of 13 concurrent
jobs, **9 were `main` push runs** — the post-merge duplicate suite of Lever 8 was
consuming two thirds of the repository's entire admission budget while three
pull requests waited on their last two workflows each. That is the clearest
single observation of what Lever 8 costs.

Two samples suggested a fluctuation, six suggested a climb, eight show a ramp
then a plateau. That is the ramp rule applying to itself. So the figure is not a fixed cap being hit — it is a
level that moves, and it doubled inside a quarter of an hour while the queue depth
barely changed.

That is worth stating carefully, because the tempting reading of the first sample
was "the effective cap is five", and repeating a measurement eleven minutes later
falsified it. **A single sample of this number is not evidence of a ceiling.**
Anyone re-measuring should take samples minutes apart before concluding anything,
and should expect a ramp rather than a step.

**What this does not establish is why**, but one candidate can be bounded and
largely ruled out. Expanding every matrix in every workflow gives **166 jobs, of
which 53 (32%) sit behind a `needs:` and 113 (68%) are free to start
immediately**. So `needs: build` serialisation cannot explain five: two thirds of
a wave's jobs have no dependency at all, and with ten waves open there are
hundreds of ungated jobs eligible to run at any moment while five, then ten, do.

That leaves scheduler behaviour and runner availability, neither of which is
observable through the API. Naming what is ruled out and what is not beats a
tidy answer: the cause is **not** the cap and **not** dependency serialisation,
and beyond that this document should not guess.

The plateau reading is now available, and it **restores the original conclusion**:
the level settles around **12, against a cap of at least 20**. It is not pressed
against the ceiling, so raising the cap still buys nothing.

I flagged that conclusion as provisional at 15-and-climbing, and was right to —
had the ramp stopped at 20 it would have inverted. It stopped at about 12.

**The plateau test has a confound worth stating, because it nearly invalidated
this reading.** Queue depth fell from roughly 200 runs to 87 during the sampling
window. A level that falls because the queue is draining looks exactly like a
level that has plateaued against nothing. The test is only sound while depth
stays comfortably above the cap — and 87 queued against a cap of 20 is still
four times the ceiling, so admission was never depth-limited here. Had depth
fallen to ~20 the reading would have been uninterpretable and the measurement
would need retaking under load. The earlier peak measurement
of 20 was taken during a single large wave; ten simultaneous waves do not
reproduce it. Any future cap work should re-measure first, over several samples,
and stop if the observed level is still well under the cap.

It also rules out a per-pull-request limit of five: one branch alone accounted for
6 of the 10 concurrent jobs.

### Why one pull request drains and another never starts

Three of my pull requests were open simultaneously with comparable check counts.
One drained steadily; the other two sat at **zero started** for the whole session
despite 112 eligible queued checks between them. That is not round-robin, and it
is worth knowing which it is, because it decides whether a second pull request is
worth opening at all.

Run creation times settle it:

| PR | first run created | outcome |
| --- | --- | --- |
| #112 | 03:39:21Z | draining, 7 concurrent jobs |
| #97 | 03:42:47Z | 0 of 36 runs started |
| #113 | 03:47:45Z | 0 of 32 runs started |

At the same instant, every `in_progress` run in the repository was created inside
a **90-second window, 03:39:39Z–03:41:00Z**. So the scheduler is working through
runs in roughly the order they were created, and #97's runs — queued three
minutes later — are behind an entire batch, not behind three minutes of work.

It is not *strictly* first-in-first-out: 44 queued runs were older than the
newest running one, some created the previous day on a since-merged branch.

That signal invited an obvious explanation — a clogged queue full of stuck runs —
and it is wrong. Of 219 queued runs, **213 are under an hour old and only 6
exceed it: 2.7%**. The queue is genuinely live, and **the non-FIFO ordering is
therefore not explained by staleness.** This matters for anyone building on the
scheduling finding above: the ordering anomaly is real and still unexplained,
rather than an artefact of dead entries, and queue-depth figures here can be
taken at face value.

**The practical consequence: a pull request's wait is set by how much was queued
before it, not by how many pull requests are open.** Opening a second one does
not halve anyone's throughput; it joins the back of a queue and waits. The
corollary is that rebasing is worse than it looks — a rebase does not merely
discard accumulated green checks, it moves the branch from wherever it sat in the
queue to the very back of a ~200-run line.

### A fifth of the queue is the post-merge duplicate suite

The ordering residue above — 44 queued runs older than the newest running one,
with staleness ruled out at 2.7% — turns out to have a single dominant cause.
Broken down by event and branch:

| | count |
| --- | --- |
| `push` on `main` | **32** |
| `pull_request` | 12 |

**32 of the 44 are `push` events on `main`**, and repo-wide they are **20% of the
entire 158-run queue**. Note the unit: these are *runs*. A related figure for the
bulk re-arm of three cancelled pull requests was first quoted as ~360 and is
actually **~181 runs** — the larger number counted check-runs. The runs-versus-
check-runs distinction is easy to lose the moment a figure is quoted twice. 29 of them were triggered by one merge (`e6c194c6`), were
45 minutes old at the time of measurement, and had not started.

This is the same duplication measured in *Lever 4* — every merge re-runs on `main`
a suite the pull request already proved green, because branches are rebased
immediately before merging so the merged tree is byte-identical to the tested
head. What is new is the cost. Lever 4 priced it in minutes; the real price is
**queue position**. Those 32 runs sit ahead of live pull-request work in a queue
where two of my own pull requests have had zero jobs admitted for the entire
session.

That reframes the lever. Dropping `push: main` from the workflows that already
run on `pull_request` is not a minutes saving — it is a **20% reduction in queue
depth**, and it directly buys admission for work that is actually waiting on a
review decision.

The safety caveat from Lever 4 still applies and still bounds the change:
rebasing guarantees identity only against the `main` you rebased *onto*, so if
two pull requests merge close together the second one's merged content is not
what its checks proved. Keep a small sentinel set — `pr-fast` and `heavy-guards`
— on `push: main`, and drop it from the rest.

One straggler is worth noting for whoever does it: a queued `push` run on a
merged branch was **1369 minutes old**, roughly 23 hours. It is a rounding error
in the queue, not a cause, but it shows nothing reaps these.

### The ordering model, tested against a prediction it could have failed

The scheduling model above — admission in roughly the order runs were created —
was built to explain why one pull request drained while two did not. A model
built to explain what you already saw is worth little. This one then made a
prediction, and the prediction was checkable.

#97's runs were created at **03:42:47Z**, #113's at **03:47:45Z**, five minutes
apart. When the model was written, the in-progress creation window was
**03:39:39Z–03:41:00Z** and both were unstarted. The model predicts that as the
window advances it must admit #97 first, and #113 only about five minutes of
queue later — not both together, and not #113 first.

Twenty-five minutes later the window had advanced to
**03:41:47Z–03:42:50Z**. #97 was admitted, with four jobs running. #113, five
minutes younger, was still at zero.

The window advanced monotonically and picked up #97 exactly when it reached
#97's creation timestamp. The model could have failed here — simultaneous
admission, or #113 first, would have falsified it — and it did not.

It then passed a second time. #113, five minutes younger, was admitted about
nine minutes after #97 and not before it, in the order and roughly the spacing
the model requires. **Two confirmations on predictions that could have failed is
a materially stronger result than the original fit**, which merely explained
something already observed.

### Two truncation artifacts, and why they need different defences

Both make a partial answer look finished. They are not the same bug and
pagination only fixes one.

**A complete set reported short.** `/commits/{sha}/check-runs` caps at 100 per
page. The set is final; the tool under-reports it. *Tell:* a total of exactly
100. *Defence:* `gh api --paginate`.

**An incomplete set reported as complete.** Every row is real, nothing is missing
from the page, and the total simply is not final yet — GitHub is still creating
runs for the head. *Tell:* the total changes between two paginated samples.
*Defence:* none available from a single sample; only `queued == 0` settles it.

The second one is worse, because pagination gives false confidence that it has
been handled. Measured on one pull request, all reads paginated:

| time | total | outstanding |
| --- | --- | --- |
| 04:37 | 54 | 40 |
| ~04:41 | 71 | 47 |
| 04:42 | **115** | **86** |

That pull request went from *closest to landing* to *furthest from landing* in
five minutes without a single check failing, because its denominator doubled
while being watched.

**Rule: `outstanding` is only comparable between pull requests whose total has
been stable across at least two paginated samples.** Ranking by it while runs are
still being created ranks the observation, not the work. I got this wrong three
times in one session, and the shape was identical each time — a label outliving
the measurement that produced it: carried forward from an earlier pulse, then
computed from a truncated page, then computed from a growing denominator.

### Was the ramp sampler subject to the same artifact?

A fair objection, given the above. It was not. The sampler counts **in-progress
jobs repo-wide** from the runs endpoint; it never divides by any pull request's
total, so a growing denominator cannot move it.

The finding actually cuts the other way. Runs were still being *created*
throughout the sampling window, so arrivals were ongoing and queue depth was
being replenished rather than monotonically drained. That strengthens the
condition the plateau reading depends on — depth remained far above the cap, so
admission was never depth-limited — rather than undermining it.

### Rank landers by outstanding *runs*, not outstanding *checks*

Ranking pull requests by outstanding check-runs is measuring the wrong unit, and
it produces an order that is not merely imprecise but inverted.

Same three pull requests, same instant, two endpoints:

| PR | check-runs outstanding | **runs outstanding** | what is left |
| --- | --- | --- | --- |
| #97 | 62 of 119 | **2 of 36** | `Heavy Guards`, `PR Fast` |
| #112 | 61 of 116 | **2 of 33** | `Heavy Guards`, `PR Fast` |
| #113 | 70 of 115 | **8 of 32** | those two plus six Cranelift phase workflows |

By checks, all three look roughly half finished. By runs, #97 and #112 are **34 of
36 and 31 of 33 complete**, each waiting on the same two workflows.

The reason is matrix expansion. `Heavy Guards` and `PR Fast` are the two large
matrix workflows in this repository, so a single unadmitted run of either carries
tens of queued check-runs with it. A pull request can be 94% done by run and
appear 47% done by check.

That also explains a flat completed count that looked like a stall. #112's
succeeded count did not move across four samples spanning nine minutes, which is
consistent with slot starvation and equally consistent with a stuck job. It was
neither: **all of its remaining work sits inside two runs that have not been
admitted yet.** Nothing was stuck; there was simply nothing eligible to complete.
The check-runs endpoint reported 2 in-progress for it while the runs endpoint
reported none — the same lag that makes the jobs view authoritative.

**That diagnosis then predicted a distinctive later behaviour, and got it.**
Starvation and a stuck job both predict the count stays flat or trickles. The
runs-unit explanation predicts something different and specific: nothing, then a
*step*, as a whole matrix run is admitted at once. Five minutes later #112 jumped
**55 → 63 successes** after four samples flat at 55. Step-function drain is the
signature of the runs-unit explanation and is inconsistent with both alternatives
that were ruled out. A diagnosis that anticipates a distinctive later observation
is worth more than one that merely fits the data already in hand, and this
document should be read as having the former.

It also settles what a rate term would have done here. A rate computed on
check-runs would have read #112 as draining at **zero** while it was two runs from
finished. **A rate on the wrong unit is worse than no rate, because it is
confidently wrong in the direction of that unit's error.** If a rate belongs
anywhere, it belongs on runs.

**A lander order needs three things, and each fixes a failure the previous one
does not:** paginate, or a complete set reads short; require a stable total, or
an incomplete set reads complete; and rank by outstanding **runs**, because
that is the unit admission actually operates on. A rate term — Δcompleted across
two timestamped samples — is the natural fourth, but on this evidence it would
have mis-ranked too: #113 was draining fastest at roughly 5 checks per minute
while being the furthest from landing by runs.

### A pre-registered prediction, and it failed

Three pull requests had been cancelled wholesale and were re-armed, putting a
known quantity of work into the queue at a known moment. Before it landed, two
outcomes were written down:

- if the plateau of ~11 is a genuine admission ceiling, queue depth steps up and
  in-progress jobs stay at ~11;
- if depth was ever the limiter, in-progress jobs rise with depth.

Measured across the arrival edge:

| | in-progress jobs | queued runs |
| --- | --- | --- |
| before, 04:53:21 | **12** | 17 |
| after, 04:56:13 | **2** | 199 |
| confirm, 04:57 | **2** | 199 |

Queue depth stepped by 182 runs, matching the arrival. **In-progress jobs did not
hold at 11 and did not rise. They collapsed to 2**, an 83% drop, confirmed on an
independent sample with only one workflow run executing repository-wide.

Neither branch of the prediction survived. The result is not a refinement of the
plateau model; it contradicts the assumption both branches shared — that
admission is a function of the cap and the depth, monotone in each. A twelve-fold
increase in depth reduced admission by six-fold.

**No mechanism was claimed at the time.** A burst of arrivals appearing to
*suspend* admission rather than saturate it is consistent with a scheduler
reshuffle, a rate limit on run creation competing with dispatch, or an artefact
of how the API reports state during a large enqueue.

**That claim was retracted.** It was wrong, and the way it was wrong matters more
than the claim did.

Later samples appeared to show admission falling to zero and staying there — 2
jobs, then 1, then 0 — and this document briefly asserted a repository-wide
availability failure. **Dispatch never stopped.** At the moment "0 in-progress
jobs" was recorded, a job named `Level 1 contracts` had been executing for over
nine minutes and continued afterwards. Jobs were being dispatched continuously
across the entire window.

**The instrument was at fault, and it is the same class of error this document
catalogues elsewhere.** The sampler counts in-progress jobs by first asking
`runs?status=in_progress` and then enumerating jobs within those runs. When that
endpoint transiently reports zero runs — as it does, being subject to exactly the
lag that makes the jobs view authoritative over check-runs — the job count is
zero regardless of what is actually executing. **The "authoritative" jobs view
was never independent: it was gated on the endpoint whose lag it was supposed to
correct.**

Two rules follow, and the second is new:

- **A check whose passing condition is satisfiable by a momentary zero must
  require that zero to persist across spaced samples.** The empty-set guard
  protects the numerator; nothing protected against a transient zero. Two samples
  two minutes apart looked like persistence and were not.
- **A derived metric inherits every defect of the endpoint it is derived from.**
  Calling the jobs view authoritative was correct about check-run lag and wrong
  about independence.

**This casts a caveat back over the ramp curve.** The plateau's *level* — around
11 — is an average over twelve samples and is probably sound. Its *variance*, the
8–15 oscillation, is not trustworthy: an unknown share of the low readings may be
the runs endpoint under-reporting rather than admission genuinely dipping. The
same doubt applies to the 12 → 2 "collapse", which must be re-derived in job
units measured independently of run status before it is called a collapse at all.

A correction that costs something is the test of the standard set earlier in this
document for reporting a failed prediction. This one cost a section.

What can be said is narrower and still useful:

- The plateau of ~11 measured over 33 minutes describes a *steady state*, not a
  ceiling. It does not survive a large arrival, so it should not be used to
  predict behaviour during one.
- **Every drain estimate in this document assumes steady state.** Anyone
  estimating time-to-green across a period containing a bulk re-arm — a lane
  clearing and re-dispatching its train, for instance — should expect the
  estimate to be wrong by a large factor, in the pessimistic direction.
- The earlier conclusion that *raising the cap buys nothing* was reached at
  depths of 87–200 with admission at 8–15, and is unaffected: admission was
  nowhere near the cap before the arrival, and is further from it after.

**Every timing figure in this document must be read with the queue depth it was
measured at.** Under starvation — one execution slot against seventeen queued
runs, with `actions/runners` reporting **zero** self-hosted runners — measured job
duration is dominated by scheduling, not by the job. A throughput edge derived
from wall-clock during such a window measures GitHub's queue, not the change it
is attributed to. Edges measured at different depths are not comparable
quantities, and this document did not previously say so.

A prediction that fails is worth recording more carefully than one that survives,
because the failure is where the model was actually wrong. This one was written
down before the event precisely so it could not be quietly reinterpreted
afterwards.

### A gate phrased as the absence of a bad reading passes on no reading at all

Three defects in this document look unrelated and are one defect. Each was found
separately; stating them as a list invites a fourth guard for the fourth
instance. They generalise instead.

| instance | how nothing was supplied |
| --- | --- |
| empty result set | a paginated query returned no rows and the gate read *open* |
| momentary zero | a dispatch gap read as *nothing running*, twice, two minutes apart |
| all-`cancelled` set | 65 of 65 runs `cancelled`: zero pending, zero failures, **zero evidence** |
| abbreviated SHA | `runs?head_sha=` returns `total_count: 0` for an 8-char SHA — no error, no warning |

The last is the sharpest. A filter that silently matches nothing is
indistinguishable from a condition genuinely met, and it produces a confident
zero from a typo.

**The general form: a gate phrased as the absence of a bad reading is satisfiable
by the absence of any reading.** Every instance above supplies nothing and is
scored as success.

**The repair is not a fourth guard. It is inverting the predicate**: require the
*presence* of `success` on every required workflow, and require the count of
successes to equal the count of required runs. Presence cannot be satisfied by
nothing, so the inversion subsumes all four instances and the ones not yet seen.

**A fifth arrived after the inversion was written, and the inversion already
rejected it.** `queued` is a status that reports the run's own state perfectly
accurately while saying nothing whatever about whether it will ever complete. It
is not an error, so an absence gate waves it through once pending is
miscounted; the presence gate cannot be satisfied by it, because a queued run
supplies no `success`. **An inversion earns its keep when it absorbs a case
discovered after it was written** — that is the argument for preferring it to a
growing list of guards, and this is the first case to test it.

One reconciliation worth recording, because the gate's equality depends on it.
The runs endpoint returns **36 runs for a head SHA: 35 `pull_request` plus one
`push`** (`Codex Trusted Gate`). Filtering to `pull_request` gives a different
denominator, and a gate comparing `success` from one event set against `total`
from another cannot pass. This gate counts every event, which is also the
fail-closed direction: a stuck non-pull-request gate blocks the merge rather than
being invisible to it.

This was not hypothetical here. The merge watcher used in this session gated on
"zero pending and zero failures". Three pull requests in this repository sat at
65, 64 and 63 runs *entirely* `cancelled` — zero pending, zero failures — and
that gate would have merged them on no evidence whatever. It was rewritten to
require `success == total`, with a non-emptiness assertion and a 40-character SHA
check, before it could fire.

### The forty-sample re-derivation, which refutes the section above

The collapse reading was drawn from two samples. The sampler ran to completion
and produced **forty samples over 1h55m**, spanning queue depths from 16 to 383 —
a 24-fold range. That is enough to test the claim properly, and it does not
survive.

| | |
| --- | --- |
| in-progress jobs | min 1, max 17, **mean 8.9** |
| queue depth | min 16, max 383 |
| **Pearson r(jobs, depth)** | **+0.49** |
| mean jobs at depth < 100 (n=10) | **5.4** |
| mean jobs at depth ≥ 100 (n=30) | **10.1** |

Admission is **positively** correlated with depth. Concurrency is roughly twice as
high when the queue is deep than when it is shallow — the opposite direction from
the "12 → 2 collapse" this document asserted, and the opposite of what a
depth-limited system would show.

**So the 04:58 conclusion was wrong, and wrong in a specific way worth naming.**
It took two samples straddling a bulk arrival, observed depth up and jobs down,
and concluded that admission was non-monotone in depth — a claim about mechanism,
from n=2, with the confounder in plain sight. The arrival itself is the
confounder: 181 runs were created in one burst, and a run counted as executing
only once its `status` field says so, which lags creation. The instrument reads
low exactly when many runs have just been created. The collapse is an artefact of
sampling at the arrival edge, not a property of the scheduler.

What survives is narrower and better supported than either claim:

- Admission sits around **9 jobs on average**, ranging 1–17, against a cap of at
  least 20 — so the cap is not the binding constraint, which was the original
  conclusion and is the one thing that has held throughout.
- Depth does not suppress admission. If anything it accompanies more of it,
  presumably because both track overall repository activity rather than one
  causing the other. **No causal claim is made in either direction**; that is the
  error this section exists to correct.

A prediction that fails is worth recording. A conclusion drawn from two samples
and refuted by forty is worth recording more loudly, because the failure was not
in the prediction but in thinking two points were enough to replace it.

### One error class, four instances: a correct measurement in the wrong unit

Every wrong number in this document came from the same place, and it was never
the arithmetic.

| what was wrong | claimed | actual | unit confused |
| --- | --- | --- | --- |
| lander order | #113 closest | #113 furthest | check-runs vs **runs** |
| bulk re-arm size | ~360 | **~181** | check-runs vs **runs** |
| failures on one PR | 1, then 2 | **3** | jobs vs **runs** |
| "runs appear on unchanged SHAs" | established | **disconfirmed** | check-runs vs **runs** |

In each case the query was well-formed, the data was real, and the count was
correct *for the unit it was counting*. Nothing looked wrong, because nothing was
wrong except which noun was being counted.

Two structural remarks, both of which generalise past CI.

**The unit is chosen before the measurement and remembered afterwards, so it is
invisible at the point of use.** A number carried across two sentences loses its
unit long before it loses its precision. That is why the re-arm figure survived
being quoted twice at ~360 while the underlying data said ~181.

**The remedy is the same one that fixed the prose-versus-gate drift: report the
partition, not a label.** `runs`, `jobs` and `check-runs` are three different
partitions of the same work; a figure that names its partition cannot be silently
compared against a figure from another. Every count in this section now carries
its noun for that reason.

Recorded here rather than in `docs/ONE_WAY_LEDGER.md`, which is a ledger of
compiler one-way rules where each row must carry a reproduction against the
compiler. This is observability methodology and would be a category mismatch
there.

### What it implies

At 1.1–2.4 checks per minute against ~500 queued, a single pull request of ~55
checks is **roughly half an hour to an hour from green even with the whole
machine to itself**, and it never has that. Three of mine together are a
multi-hour proposition.

The practical consequences for anyone working here:

- **A push is expensive in a way the per-wave levers do not capture.** Rebasing a
  branch discards its accumulated green checks and re-enters the back of a
  ~500-deep queue. Freeze pushes while a wave drains, and rebase only when the
  branch is genuinely unmergeable.
- **Opening a pull request costs the whole repository, not just its author.** Any
  change to a root Markdown file triggers the full suite, because `pr-fast.yml`
  has no path filter. This section was itself held back from being opened as a
  pull request until a wave landed, for exactly that reason.
- **The binding constraint is neither the workflows nor the cap.** Levers 1 to 5
  all cut work per wave, and none of them helps when ten waves are queued. But
  the cap is not what they are queued behind either — measured concurrency is
  five against a cap of at least 20. Until the cause of that is identified, both
  the per-wave levers and the Pro-plan item are optimising the wrong thing.
- **`pr-fast.yml` has no path filter**, so a change touching only a root Markdown
  file triggers the full ~55-check suite. At five-way concurrency that is about
  half an hour of the repository's total throughput spent proving that a document
  did not break the compiler.

  The obvious objection is the guard scripts that read this workflow, and it does
  not hold. **15 scripts reference `pr-fast.yml`, and every one of them asserts
  only that the string `run: just <guard>` appears in it.** None asserts anything
  about `on:`, `paths:`, or triggers — checked. Adding a path filter leaves every
  one of those assertions untouched, so the coupling that looks like it makes this
  lever expensive does not exist.

  That makes this the cheapest unclaimed lever in the document. Written out as an
  actionable item:

  **Lever 7 — docs-only fast path for `pr-fast.yml`.** *Owner: CI/guard lane.*
  Add `paths-ignore` for root Markdown (`*.md`) to `pr-fast.yml`'s `pull_request`
  trigger. **Cost:** one YAML key; no code change; no guard-contract risk, since
  all 15 scripts that read this workflow assert only on `run: just <guard>` lines.
  **Buys:** ~55 checks per documentation-only pull request. At the drain rates
  measured here that is roughly half an hour of whole-repository throughput per
  such PR, and this document alone has generated several.
  **Risk:** a documentation change that silently breaks a guard script would no
  longer be caught by PR Fast. Mitigated by keeping `justfile`, `scripts/**` and
  `.github/**` outside the ignore list, so only genuinely inert files skip.
  **Do not** extend it to `TASK*.md` or `GEMINI.md`: guard scripts assert on the
  contents of those, so they are not inert.

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
| 2026-08-19 | Lever 3a merged: build job split from Level 1 contracts | — |
| 2026-08-19 | **Measured on `main` @ `bc40864`, clean queue** | PR Fast 133m → **81m** |

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
