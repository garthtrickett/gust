#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root"
python3 scripts/phase16_unsized_abi.py --check
