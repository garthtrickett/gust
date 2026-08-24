#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

registry="scripts/cranelift_feature_registry.json"
evidence_dir="build/guards/phase19_self_compilation"
tmp_root="$(mktemp -d)"
declare -a worktrees=()
declare -A outputs=()

cleanup() {
  local worktree
  for worktree in "${worktrees[@]}"; do
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
  done
  rm -rf "$tmp_root"
}
trap cleanup EXIT

mkdir -p "$evidence_dir"
find "$evidence_dir" -maxdepth 1 -type f -name 'patch-19.*.diff' -delete

resolve_seed_commit() {
  local subject="$1"
  local resolved
  resolved="$(git log --format=$'%H\t%s' -- gust_v4.c | awk -F $'\t' -v subject="$subject" '$2 == subject { print $1; exit }')"
  if [ -z "$resolved" ]; then
    echo "Cannot resolve seed commit '$subject'; Historical Full needs fetch-depth 0." >&2
    exit 1
  fi
  printf '%s\n' "$resolved"
}

baseline_commit="$(resolve_seed_commit 'bootstrap: regenerate seed after phase 19.2')"
current_seed_subject="$(jq -r '.phase19_self_compilation_differential.current_seed_subject' "$registry")"
current_seed_commit="$(resolve_seed_commit "$current_seed_subject")"

resolve_pr_merge() {
  local pr="$1"
  local marker="Merge pull request #${pr} "
  local resolved
  resolved="$(git log --all --merges --format=$'%H\t%s' | awk -F $'\t' -v marker="$marker" 'index($2, marker) == 1 { print $1; exit }')"
  if [ -z "$resolved" ]; then
    echo "Cannot resolve Phase 19 PR #${pr}; Historical Full needs fetch-depth 0." >&2
    exit 1
  fi
  printf '%s\n' "$resolved"
}

compile_revision() {
  local label="$1"
  local commit="$2"
  local worktree="$tmp_root/$label"
  git worktree add --detach "$worktree" "$commit" >/dev/null
  worktrees+=("$worktree")
  (
    cd "$worktree"
    CC=cc CFLAGS="-O0 -w -pthread" make gust >/dev/null
  )
  outputs["$label"]="$worktree/build/gust_compiler.c"
}

compile_revision baseline "$baseline_commit"
if ! cmp -s "${outputs[baseline]}" "$tmp_root/baseline/gust_v4.c"; then
  echo "Phase 19.2 baseline build does not reproduce its committed seed." >&2
  exit 1
fi

previous_commit="$baseline_commit"
previous_output="${outputs[baseline]}"
last_boundary=""
last_compiler_commit="$baseline_commit"

while IFS=$'\t' read -r patch pr; do
  boundary_commit="$(resolve_pr_merge "$pr")"
  if ! git merge-base --is-ancestor "$previous_commit" "$boundary_commit"; then
    echo "Patch $patch boundary PR #$pr is not ordered after the preceding boundary." >&2
    exit 1
  fi

  mapfile -t expected_subjects < <(
    jq -r --arg patch "$patch" \
      '.phase19_self_compilation_differential.patch_boundaries[] | select(.patch == $patch) | .compiler_commit_subjects[]' \
      "$registry"
  )
  mapfile -t actual_subjects < <(
    git log --reverse --format='%s' "$previous_commit..$boundary_commit" -- 'compiler/*.gst'
  )
  boundary_compiler_commit="$(
    git log -1 --format='%H' "$previous_commit..$boundary_commit" -- 'compiler/*.gst'
  )"
  if [ -n "$boundary_compiler_commit" ]; then
    last_compiler_commit="$boundary_compiler_commit"
  fi
  if ! diff -u \
      <(printf '%s\n' "${expected_subjects[@]}") \
      <(printf '%s\n' "${actual_subjects[@]}") >/dev/null; then
    echo "Patch $patch compiler-source commit attribution drifted." >&2
    printf 'expected: %s\n' "${expected_subjects[*]}" >&2
    printf 'actual: %s\n' "${actual_subjects[*]}" >&2
    exit 1
  fi

  label="patch-${patch/./-}"
  compile_revision "$label" "$boundary_commit"
  current_output="${outputs[$label]}"
  diff_status=0
  diff -u --label "before-$patch.c" --label "after-$patch.c" \
    "$previous_output" "$current_output" >"$evidence_dir/patch-$patch.diff" || diff_status=$?
  if [ "$diff_status" -gt 1 ]; then
    echo "Unable to enumerate the Patch $patch compiler-C difference." >&2
    exit "$diff_status"
  fi
  if [ "$patch" = "19.7" ] && [ "$diff_status" -ne 0 ]; then
    echo "Patch 19.7 must remain the zero compiler-C diff transition." >&2
    exit 1
  fi
  if [ "$patch" != "19.7" ] && [ "$diff_status" -eq 0 ]; then
    echo "Patch $patch unexpectedly produced no compiler-C difference." >&2
    exit 1
  fi

  numstat="$(git diff --no-index --numstat "$previous_output" "$current_output" 2>/dev/null || true)"
  printf 'Patch %s / PR #%s | %s\n' "$patch" "$pr" "$numstat"
  previous_commit="$boundary_commit"
  previous_output="$current_output"
  last_boundary="$boundary_commit"
done < <(
  jq -r '.phase19_self_compilation_differential.patch_boundaries[] | [.patch, (.pull_request | tostring)] | @tsv' "$registry"
)

if ! git merge-base --is-ancestor "$last_compiler_commit" "$current_seed_commit"; then
  echo "The current seed predates the final accounted compiler-source change." >&2
  exit 1
fi
git show "$current_seed_commit:gust_v4.c" >"$tmp_root/phase19-current-seed.c"
if ! cmp -s "$previous_output" "$tmp_root/phase19-current-seed.c"; then
  echo "Final accounted Phase 19 compiler build does not reproduce its named converged seed." >&2
  exit 1
fi

full_numstat="$(git diff --no-index --numstat "${outputs[baseline]}" "$previous_output" 2>/dev/null || true)"
IFS=$'\t' read -r full_insertions full_deletions _ <<<"$full_numstat"
expected_insertions="$(jq -r '.phase19_self_compilation_differential.full_diff.insertions' "$registry")"
expected_deletions="$(jq -r '.phase19_self_compilation_differential.full_diff.deletions' "$registry")"
if [ "$full_insertions" != "$expected_insertions" ] || [ "$full_deletions" != "$expected_deletions" ]; then
  echo "Full compiler-C differential drifted: expected ${expected_insertions}/${expected_deletions}, got ${full_insertions}/${full_deletions}." >&2
  exit 1
fi

echo "guard-cranelift-phase19-self-compilation-differential: ok (${full_insertions} insertions, ${full_deletions} deletions, 0 unexplained, Level 3)"
