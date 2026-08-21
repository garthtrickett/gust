#!/usr/bin/env bash
# Patch 19.2 focused semantic parity: exercise the new record while proving
# that the Patch 19.1 codegen baseline remains unchanged.
set -euo pipefail

just guard-positive \
  compiler/typechecker_brand_identity_test_entry.gst \
  phase19_brand_identity_authority

bash scripts/phase19_rename_invariance.sh

echo "guard-cranelift-phase19-brand-authority-parity: ok (record semantics and unchanged codegen baseline, Level 2)"
