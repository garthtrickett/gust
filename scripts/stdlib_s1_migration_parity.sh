#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

migrated="tests/e2e_sync_primitives.gst"
build_dir="build/guards/stdlib_s1_migration"

for path in "$migrated" docs/STDLIB_S1_MIGRATION.md; do
  if [ ! -f "$path" ]; then
    echo "Missing S1.11 evidence: $path" >&2
    exit 1
  fi
done

# The migration's whole claim: no manual cleanup path remains. Before S1.11 this
# file held four Lock/Unlock pairs, every one inside `unsafe`. After it, the
# mutex is reachable only through the safe surface and release is by scope exit.
if rg -n -F -e '.Lock()' -e '.Unlock()' "$migrated" >/dev/null 2>&1; then
  echo "S1.11: migrated file still contains a raw Mutex call." >&2
  exit 1
fi
rg -n -F 'sync.lock(' "$migrated" >/dev/null
rg -n -F 'sync.get(' "$migrated" >/dev/null

# No raw-pointer workaround was introduced in place of the removed unlocks. The
# only `unsafe` blocks that may remain are the channel operations and the
# spawn-argument dereference, which are the pre-existing fiber ABI and are not
# mutex operations.
if rg -n -F 'mutex.Lock' "$migrated" >/dev/null 2>&1; then
  echo "S1.11: mutex reached outside the safe surface." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"
make gust >"$build_dir/make-gust.log" 2>&1

# Identical observable behaviour and synchronization guarantees: the producer
# sends 0..4, the consumer accumulates them under the guard, and the program
# settles at exactly 10. A lost or double release would hang the settle loop
# rather than print a wrong number.
if ! GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE=mir-to-c \
    timeout 90s bash scripts/run-gust-file.sh "$migrated" \
      >"$build_dir/runner.stdout" 2>"$build_dir/runner.stderr"; then
  cat "$build_dir/runner.stdout" >&2
  cat "$build_dir/runner.stderr" >&2
  echo "S1.11 migrated program failed or timed out." >&2
  exit 1
fi
cp to.log "$build_dir/migrated.log"
test ! -s "$build_dir/runner.stderr"
rg -N -x -F '10' "$build_dir/migrated.log" >"$build_dir/observable"
printf '10\n' >"$build_dir/expected"
cmp -s "$build_dir/expected" "$build_dir/observable"

# The raw-Mutex inventory must record this migration. Patch 24.3e registered the
# removal successor; without it the contract rejects a migrated source.
python3 scripts/phase20_unsafe_mutex_migration.py validate >/dev/null

echo "guard-stdlib-s1-migration: ok (four manual cleanup paths removed; mutex reachable only through the safe surface; observable 10 unchanged; raw-Mutex inventory records the removal)"
