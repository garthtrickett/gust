#!/usr/bin/env bash
set -euo pipefail

family="${1:-}"
if [ -z "$family" ]; then
  echo "usage: scripts/phase14_composition_differential.sh <phase14-family>" >&2
  exit 2
fi

python3 scripts/phase14_composition.py validate
python3 scripts/phase14_composition.py validate-family "$family"
bash scripts/phase13_registry_differential.sh "$family"