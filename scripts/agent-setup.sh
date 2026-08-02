#!/usr/bin/env bash
set -euo pipefail

required_commands=(
  bash
  make
  cc
  cargo
  python3
  rg
  just
  git
)

missing=0
for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "Codex environment tools:"
cc --version | head -n 1
cargo --version
python3 --version
rg --version | head -n 1
just --version
git --version