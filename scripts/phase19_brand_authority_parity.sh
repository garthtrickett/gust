#!/usr/bin/env bash
# Phase 19 brand-authority parity: exercise the Patch 19.2 record and the
# current rename-invariance transition owned by the active naming patch.
set -euo pipefail

just guard-positive \
  compiler/typechecker_brand_identity_test_entry.gst \
  phase19_brand_identity_authority

bash scripts/phase19_rename_invariance.sh

echo "guard-cranelift-phase19-brand-authority-parity: ok (record semantics and rename transition, Level 2)"
