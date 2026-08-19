# Gust Agent Instructions

Read `GEMINI.md` before editing code.

## Lanes

Two roadmaps are active in parallel. Each agent works exactly one lane and reads
exactly one roadmap.

| Lane | Roadmap | Branch prefix | Owns |
| --- | --- | --- | --- |
| Cranelift | `TASK.md` | `codex/phase<N>-<patch>-<slug>` | canonical MIR, native lowering, backend parity, target/object/linker authority |
| Stdlib | `TASK_STDLIB.md` | `codex/stdlib-` | safe stdlib surface, ergonomics, stdlib tests, examples, documentation |

Everything in this file applies to both lanes. Where it says *the active
roadmap*, read `TASK.md` in the Cranelift lane and `TASK_STDLIB.md` in the
Stdlib lane.

If the requested work does not clearly belong to one lane, stop and ask. Do not
pick a lane by convenience.

The Cranelift lane keeps the branch naming it already uses — `codex/phase18-5-target-abi`,
`codex/phase18-4-relocations`, and so on. That pattern already identifies the
lane, and renaming it mid-phase would churn a running loop for no benefit. The
Stdlib lane is new, so it takes an explicit `codex/stdlib-<feature>` prefix. What
matters to CI is the `codex/` namespace itself, not the suffix — see Branch and
publication policy.

## Objective

Complete one explicitly requested roadmap patch at a time. Make the smallest
coherent, bootstrap-safe change that satisfies the selected patch.

## Ownership boundaries

The Cranelift lane owns canonical MIR, MIR validation, native lowering,
Cranelift translation, the native backend driver, the Cranelift capability and
parity registry, native fixtures, native differential tests, ABI and
native-boundary semantics, native object emission, and backend diagnostics.

The Stdlib lane owns stdlib APIs, safe abstractions, ergonomics, stdlib tests,
compile-fail tests, examples, documentation, collection usability, string
usability, and safe synchronization wrappers.

The Cranelift lane treats MIR-to-C as the semantic oracle unless a deliberate,
roadmap-authorized semantic correction is being made. It does not redesign
stdlib APIs except to expose a backend limitation.

The Stdlib lane composes existing semantics. It does not define new ones. See
the next section for where that line falls; it is narrower than it looks.

## Shared coordination zone

`docs/SHARED_SEMANTIC_ZONE.md` is the authoritative map of concepts neither lane
may change unilaterally. Read it before any change that touches type
representation, brands, resources, move semantics, MIR, ABI, layout, the runtime
symbol surface, operator semantics, or the fiber and mutex contracts.

When a task requires a shared-zone change, **stop the task and report**. Do not
route around the problem locally, and do not implement a narrower version of it
inside one lane. The report must state:

1. intended user behaviour;
2. the existing limitation;
3. the smallest generic semantic change required;
4. files and layers affected;
5. whether it affects MIR-to-C;
6. whether it affects Cranelift;
7. whether it affects bootstrap.

Then wait for an ownership decision. Default owner: a semantic, compiler, or MIR
change belongs to the Cranelift lane; a pure library or API change belongs to
the Stdlib lane.

## Branch and publication policy

- Base work on `main`.
- Publish agent work only through an upstream branch under `codex/`, using the
  lane prefix from the Lanes table.
- Never push directly to `main`.
- Open or update a draft pull request, then mark it ready after required checks
  pass.
- Do not self-approve. Merge only the agent's own upstream `codex/**` pull
  request after required checks pass and all review conversations are resolved.
- Do not change repository rules, Actions variables, secrets, or permissions
  unless the repository owner explicitly requests that configuration change.

The `codex/` prefix is load-bearing, not cosmetic. Verified against the
repository's `Protect main` ruleset and workflow triggers on 2026-08-19:

- The **only** required status check on `main` is `Codex / Trusted actor`. It is
  produced by `.github/workflows/codex-trusted-ci.yml`, which triggers **only on
  push to `codex/**`** and explicitly fails any ref outside that namespace.
- `.github/workflows/pr-fast.yml` runs 55 guards and gates on
  `startsWith(github.head_ref, 'codex/')`.
- `.github/workflows/heavy-guards.yml` gates on the same condition.
- All three additionally require `github.actor == vars.CODEX_GITHUB_ACTOR`, so
  the prefix is necessary but not sufficient.

A pull request from a branch outside `codex/**` therefore runs neither PR Fast
nor Heavy Guards, and never produces the one required check — so it cannot merge
and has verified almost nothing while getting there.

This is why both lanes stay inside `codex/**` and are distinguished by suffix
rather than by a new top-level namespace. The handoff document's proposed
`cranelift/<phase>` and `stdlib/<feature>` branches would be unmergeable.

The ruleset also sets `required_review_thread_resolution: true` with
`required_approving_review_count: 0`, which is what "all review conversations are
resolved" in the Merge policy refers to.

## Working tree isolation

Two lanes and one checkout do not mix. Work from a dedicated git worktree per
branch, created outside the repository directory:

```bash
git worktree add ../gust-<short-name> codex/<branch>
```

This is not tidiness. A checkout has exactly one HEAD, so if anything else
switches branches in it, your uncommitted work follows silently onto someone
else's branch and is one `git add -A` away from being committed there. Git
refuses to check the same branch out in two worktrees, which turns that failure
from likely into impossible.

Per-worktree isolation also covers the root volatiles: `gust`, `gust_bootstrap`,
`gust_program`, `gust_unsafe_program`, `to.log`, and `build/`. Two agents sharing
a checkout share those binaries, which means one agent's `make` silently decides
what the other agent's guards actually test.

### What a worktree does not isolate

`/tmp` is shared by every worktree on the machine. Around 70 fixed
`/tmp/gust-*.request` and `/tmp/gust-*.witness` paths are hard-coded across
`scripts/` and the `justfile` — `/tmp/gust-phase15-move-state.request`,
`/tmp/gust-phase16-resource-aggregate-abi.request`, and so on. Two worktrees
running the same guard family at the same time overwrite each other's fixtures
and produce a result that belongs to neither run.

A worktree isolates the repository, not the machine. Do not run the same guard
family concurrently in two worktrees. Where guards must run in parallel, let CI
provide the parallelism — it has one machine per job.

The `justfile`'s parallel Cranelift suite already creates a worktree per shard
for this reason: each shard needs its own `to.log`.

### Cleaning up

Remove the worktree when its branch merges:

```bash
git worktree remove ../gust-<short-name>
git worktree prune
```

`git worktree list` accumulates `prunable` entries from earlier phases if this is
skipped. Beyond the disk cost, it makes the list useless for its most valuable
purpose — seeing at a glance who is working where.

## Git authorization

This file is the explicit authorization for `git commit`, `git push`,
`gh pr create`, `gh pr edit`, `gh run cancel`, and `gh pr merge` on `codex/**`
branches, for whichever lane the operator has activated.

Authorization mechanics live here. **Activation** lives in the roadmap: no
implementation work begins on a lane until that lane's roadmap has been
explicitly activated by the operator, per its own Roadmap Activation section.

General rule: when Workflow, Monitoring, Merge, Phase Completion, or Runner
Policy defines the next step, continue without a permission prompt. Ask only
when the next action falls outside those policies or requires a material scope
expansion.

## Workflow policy

Start one patch → run the related `just` / `make` / `cargo` / `scripts/*` checks
locally → once local checks pass, publish through a `codex/**` branch and pull
request to trigger GitHub runners. If a GitHub runner fails, cancel superseded
runs on that branch, reproduce the first failing guard locally from the smallest
useful log excerpt, fix it, rerun the focused local guard, push, and monitor the
new `HEAD` until green. Do not poll GitHub while an unchanged local failure
remains.

When a local or GitHub runner fails, do not prompt for permission when the
active roadmap defines the next step. Fix forward within the current patch,
preserve the patch boundary, and stop only when the correction would materially
expand scope or no policy defines the next action.

**Atomic per-patch commits and PRs:** each initial publication must contain one
complete patch. Do not combine planned patches into one PR, and do not split a
patch across multiple initial PRs unless its Exit Gate explicitly requires that
split. Narrow corrective commits on the same PR are allowed when CI or review
identifies a defect; reproduce and validate each correction locally before
republishing.

## Monitoring policy

- State monitoring explicitly in chat as `Monitoring <branch> <SHA> via <monitor> every 2m`.
- Use `gh run list --branch <branch> --limit 100` and, where necessary, the
  paginated Actions API filtered to the exact `head_sha`.
- Report each poll as `SHA | workflow | event | status | conclusion` and
  distinguish the owning guard failure from unrelated or superseded runs.
- After each poll say `Monitoring continues` or `All green — proceeding`.
- Always set a 5 minute pulse when monitoring local tests or GitHub CI/CD, and
  message a status update on every pulse. This applies to long-running local
  guard families as well as cloud runs; silence during a long wait is not
  acceptable even when nothing has changed.
- Do not silently poll.

## Merge policy

Once every required `pull_request` workflow for the exact PR `HEAD` is
`completed success`, all review conversations are resolved, and repository rules
permit the operation, autonomously merge the agent's own `codex/**` pull request
without prompting.

After a capability patch merges, proceed to the next patch of the same lane only
when that lane's roadmap has been explicitly activated.

## Phase completion loop

After explicit activation, do not stop after one capability merge. A phase is
complete only when its roadmap's Status shows every patch `DONE`, every Success
Criterion is satisfied, all review conversations are resolved, and its closure
guard passes in the authoritative GitHub environment.

After merging one patch, update local `main`, create the next lane branch from
that `main`, implement the next patch's full Purpose and Exit Gate, validate
locally, publish, monitor, fix forward if needed, and merge when green. Stop only
when the operator explicitly says stop, repository policy blocks progress, or the
required correction would materially expand the selected patch.

## Cross-lane rebase discipline

The lanes share `main` and will conflict if they drift.

- After any lane merges to `main`, the other lane rebases its live branch onto
  `main` before its next push.
- A lane never edits the other lane's roadmap, guards, workflows, or registries.
- When a Stdlib patch requires a Cranelift-owned registry row (any new or
  changed `std_*` runtime symbol — see `docs/SHARED_SEMANTIC_ZONE.md`), it is a
  coordination request, not a local edit.
- Neither lane accumulates a stack of unmerged semantic changes.

## Runner policy

If a GitHub runner fails, cancel other queued or in-progress runs on that branch
that are superseded by the fix. Before a new push, cancel runs whose `headSha` is
not the current `HEAD` so obsolete jobs do not consume runner capacity. Never
cancel a current-`HEAD` run merely because it is slow. Never cancel a run
belonging to the other lane.

```bash
BRANCH=$(git branch --show-current)
PATCH_HEAD=$(git rev-parse HEAD)
export PATCH_HEAD
gh run list --branch "$BRANCH" --limit 100 --json databaseId,headSha,status,name | python3 -c "
import json, os, subprocess, sys
head = os.environ['PATCH_HEAD']
runs = json.load(sys.stdin)
seen = set()
cancelled = 0
for run in runs:
    run_id = run['databaseId']
    if run['headSha'] != head and run['status'] != 'completed' and run_id not in seen:
        seen.add(run_id)
        print(f\"cancel {run_id} {run['headSha'][:7]} {run['name']} {run['status']}\")
        subprocess.run(['gh', 'run', 'cancel', str(run_id), '--repo', 'garthtrickett/gust'], check=False)
        cancelled += 1
print(f\"cancelled {cancelled} superseded (limit 100)\")
"
```

If more than 100 runs exist, use the paginated Actions API and apply the same
exact branch, non-completed, and non-current-`HEAD` filters.

Because the branch filter is exact, this script is already lane-safe. Two lanes
running concurrently do contend for the 20-job concurrency cap; see
`CI_THROUGHPUT.md`.

## Repository rules

- Do not add dependencies without explicit approval.
- Do not access production systems or external secrets.
- Do not weaken, remove, skip, relabel, or bypass tests to obtain a pass.
- Do not make unrelated formatting or refactoring changes.
- Preserve existing architecture and ownership boundaries.
- Preserve MIR-to-C as the differential oracle until the roadmap changes it.
- Preserve explicit Cranelift no-fallback behavior. No stdlib feature may fall
  back to the C backend when Cranelift does not support it; unsupported native
  behaviour stays explicit.
- No feature may mean one thing through MIR-to-C and another through Cranelift.
  Do not teach one backend about a feature.
- Preserve Phase 9G artifact ownership.
- Do not add general lifetime algebra, arbitrary lifetime casts, arena-brand
  escape hatches, new smart-pointer families, or raw-pointer workarounds inside
  a safe stdlib surface.
- Do not special-case an individual stdlib type in a backend.
- Do not hide unsafe behaviour behind a function presented as safe.
- Do not introduce source constructs into the self-hosted compiler that the
  checked-in bootstrap seed cannot compile.

## Stop conditions

Stop and report, rather than improvising, on any of:

- a need for new lifetime syntax or arbitrary brand relationships;
- a need for a raw-pointer workaround in a safe stdlib surface;
- a need for a new MIR instruction, or a change to an existing one's meaning;
- a change to resource, drop, or move semantics;
- a change to ABI, layout, or the native runtime ABI;
- a new or changed `std_*` runtime symbol;
- a change to operator semantics;
- backend-specific stdlib semantics;
- a large unrelated compiler refactor.

Use the seven-point report format from the Shared coordination zone section.

## Validation

Run the narrowest applicable checks first:

1. relevant static or focused guards;
2. `make gust`;
3. focused native or differential tests;
4. `make test` when appropriate;
5. `make bootstrap` for bootstrap-sensitive changes;
6. `git diff --check`.

Use `scripts/agent-verify.sh` where it covers the requested validation.

Local validation is advisory. GitHub Actions is the authoritative validation
environment. A task is not complete until the required checks for the published
commit pass.

After local partial validation (relevant Level 1/Level 2 guards, not the full
historical suite), publish via a `codex/**` branch and PR, then immediately check
GitHub Actions runners with `gh run list` / `gh run view --log`. If any required
check fails, reproduce the failure locally with the exact log excerpt, fix
minimally, rerun the focused local guard, and push again. Do not consider a patch
done until the PR's required checks are green.

Test semantics, not merely compilation. Where the roadmap requires it, a change
carries a positive source test, a negative compile-fail test, a runtime behaviour
test, a MIR-to-C test, a Cranelift differential test when the feature is within
the supported cohort, and resource and brand misuse tests.

### Bootstrap seed

`gust_v4.c` is the committed, converged C seed of the self-hosted compiler (see
"The Non-Rust Bootstrap Chain" in `README.md`). `make bootstrap` compiles the
compiler a second and third time, asserts stage 2 and stage 3 are byte-identical,
and then overwrites `gust_v4.c` with the result. The seed is generated. Never
hand-edit it.

Regenerate the seed, **in its own commit and pull request with no other change**,
when:

- a patch introduces a construct into `compiler/*.gst` that the committed seed
  cannot compile — `make` fails at stage 1 when this happens;
- a patch changes lexer, parser, typechecker, or codegen behaviour that the
  compiler's own sources depend on;
- `make bootstrap` reports a convergence failure — that is a defect to diagnose
  before anything else, not something to regenerate past;
- the seed has drifted far enough behind `compiler/*.gst` that the next
  bootstrap-sensitive patch would otherwise carry the whole backlog in its diff.

Do not regenerate the seed as a side effect of an unrelated patch. The diff is
large and machine-generated, and folding it into a capability patch hides the
change actually under review.

Nothing in CI detects seed drift. It surfaces only when `make` fails, or when
someone runs `make bootstrap` and sees the diff. A long gap since the last
regeneration is a risk to retire deliberately, not evidence that all is well.

## Failure handling

- Diagnose the first failing command before modifying more code.
- Use the smallest relevant log excerpt.
- Do not repeatedly rerun an unchanged failing command.
- Do not fix unrelated pre-existing failures.
- Stop and report when the required correction would materially expand scope.

## Completion report

The task result or draft pull request must include:

- root cause or implementation rationale;
- files changed;
- roadmap and registry rows affected;
- exact validation commands;
- pass or fail results;
- known limitations;
- remaining uncertainty.
