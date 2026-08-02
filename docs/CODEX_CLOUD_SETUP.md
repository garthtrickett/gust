# Codex Cloud Setup for the Public Gust Repository

This repository keeps source public while allowing only the verified Codex
GitHub actor on upstream `codex/**` branches to consume the normal PR and
heavy GitHub Actions runners.

The scheduled Cranelift historical workflow remains an intentional
GitHub-scheduled exception. Its manual dispatch path is restricted to the same
verified Codex actor.

## 1. Record the actor used by Codex

Publish the harmless Codex Cloud integration task as a draft pull request.

In GitHub, record:

- the actor that pushed the upstream branch;
- the pull-request author;
- the exact upstream branch name.

Do not guess the actor. Codex may publish through a GitHub App, bot, or the
connected user identity depending on the integration.

If Codex publishes using the connected user's ordinary GitHub identity,
GitHub Actions cannot distinguish a Codex push from a manual push made by that
same identity. The `codex/**` namespace and protected `main` branch remain the
additional boundary.

## 2. Configure the repository variable

Open:

`Settings -> Secrets and variables -> Actions -> Variables`

Create:

`CODEX_GITHUB_ACTOR=<the exact actor recorded from the Codex push>`

The trusted workflows fail closed or skip expensive jobs while this variable
is missing or does not match.

## 3. Protect main

Create a branch ruleset for `main` that:

- requires a pull request;
- requires no independent approval for an agent-owned `codex/**` pull request;
- requires conversation resolution;
- blocks direct and force pushes;
- blocks branch deletion;
- does not allow Codex to bypass the ruleset;
- requires the stable checks produced by a trusted Codex push.

After the first trusted run, require `Codex / Trusted actor`. Add PR Fast or
Heavy Guards checks only after each selected check has completed successfully
and the repository intends every agent-owned roadmap pull request to wait for
it.

Codex may create or update a draft pull request, mark it ready after required
checks pass, and merge its own upstream `codex/**` pull request through the
protected branch. It may not push directly to `main` or bypass the ruleset.

## 4. Verify that a public fork cannot consume runners

From a separate GitHub account or fork:

1. create a branch named `codex/untrusted-fork-test` in the fork;
2. make a documentation-only commit;
3. open a pull request against `main`;
4. confirm the trusted gate does not run because the push was not made to the
   upstream repository;
5. confirm PR Fast and Heavy Guards show their root jobs as skipped and do not
   allocate runners;
6. close the test pull request without merging.

The ordinary `pull_request` event remains declared so existing repository
workflow-contract guards retain their expected surface. Expensive root jobs
run only for a matching upstream Codex push.

Do not introduce `pull_request_target` to check out or execute fork code.

## 5. First real Codex task

Submit the following bounded task after the identity and fork tests pass:

```text
Read AGENTS.md, GEMINI.md, and the relevant roadmap section.

Investigate the stage-one exit 134 failure involving
codegen_is_vector_type.

Reproduce the failure and determine the actual abort reason from
build/gust_compiler.raw.

Apply the smallest bootstrap-safe fix.

Run the narrow relevant guard, make gust, and git diff --check.
If those pass, run make test. Run make bootstrap only when required by the
affected self-hosting path.

Do not weaken tests, modify unrelated code, commit generated output, push to
main, or merge before the required checks pass and conversations are resolved.

Publish the result through an upstream codex/** branch and a draft pull
request. Include the root cause, exact commands, results, and remaining
uncertainty.
```

## 6. Initial operating policy

For the first 20 to 30 tasks:

- use one Codex attempt at a time;
- use one roadmap patch per branch;
- keep merges automated only through protected `codex/**` pull requests;
- record Codex usage, Actions minutes, retries, and accepted patches;
- do not build an automatic CI-to-Codex retry loop yet.

GitHub Actions is authoritative. Codex Cloud's sandbox checks are advisory.
