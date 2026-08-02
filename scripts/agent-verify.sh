#!/usr/bin/env bash
set -euo pipefail

mode="${1:-focused}"
shift || true

mkdir -p build/agent-diagnostics

if [[ "$#" -gt 0 ]]; then
  echo "Running focused Just recipe: $*"
  just "$@"
fi

case "$mode" in
  focused)
    make gust
    git diff --check
    ;;
  pr)
    make gust
    make test
    git diff --check
    ;;
  bootstrap)
    make gust
    make test
    make bootstrap
    git diff --check
    ;;
  *)
    echo "Unknown validation mode: $mode" >&2
    echo "Expected one of: focused, pr, bootstrap" >&2
    exit 2
    ;;
esac