#!/usr/bin/env bash
set -euo pipefail

echo "phase11_registry_differential.sh is a compatibility wrapper for the Phase 13 registry-derived differential harness."
exec bash scripts/phase13_registry_differential.sh "${1:-all}"
