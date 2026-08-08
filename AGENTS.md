# Gust Agent Instructions

Read `GEMINI.md` before editing code.

## Objective

Complete one explicitly requested roadmap patch at a time. Make the smallest
coherent, bootstrap-safe change that satisfies the selected patch.

## Branch and publication policy

- Base work on `main`.
- Publish agent work only through an upstream branch under `codex/`.
- Never push directly to `main`.
- Open or update a draft pull request, then mark it ready after required checks
  pass.
- Do not self-approve. Merge only the agent's own upstream `codex/**` pull
  request after required checks pass and all review conversations are resolved.
- Do not change repository rules, Actions variables, secrets, or permissions
  unless the repository owner explicitly requests that configuration change.
- Per `TASK.md` Workflow Policy Git authorization, publication to `codex/**` (commit/push/PR create+update/merge and superseded-run cancel) is pre-authorized — `TASK.md` is the explicit ask. General rule: if Workflow / Monitoring / Merge / Runner Policy defines the next step, do not ask the operator — continue the automated loop (includes but not limited to "say push" gating). Only ask when no policy defines the next step.

## Repository rules

- Do not add dependencies without explicit approval.
- Do not access production systems or external secrets.
- Do not weaken, remove, skip, relabel, or bypass tests to obtain a pass.
- Do not make unrelated formatting or refactoring changes.
- Preserve existing architecture and ownership boundaries.
- Preserve MIR-to-C as the differential oracle until the roadmap changes it.
- Preserve explicit Cranelift no-fallback behavior.
- Preserve Phase 9G artifact ownership.

## Validation inside Codex Cloud

Run the narrowest applicable checks first:

1. relevant static or focused guards;
2. `make gust`;
3. focused native or differential tests;
4. `make test` when appropriate;
5. `make bootstrap` for bootstrap-sensitive changes;
6. `git diff --check`.

Use `scripts/agent-verify.sh` where it covers the requested validation.

Codex Cloud validation is advisory. GitHub Actions is the authoritative
validation environment. A task is not complete until the required checks for
the published commit pass.

After local partial validation (relevant Level 1/Level 2 guards, not the full
historical suite), publish via a `codex/**` branch + PR, then immediately
check GitHub Actions runners with `gh run list` / `gh run view --log`.
If any required check fails, reproduce the failure locally with the exact
log excerpt, fix minimally, rerun the focused local guard, and push again.
Do not consider a patch done until the PR's required checks are green.

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
