#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";python3 "$root/scripts/phase16_cross_module_abi.py" --root "$root" --check
