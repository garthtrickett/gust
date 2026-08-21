#!/usr/bin/env bash
# Phase 19 brand-authority parity: exercise the Patch 19.2 record and the
# current rename-invariance transition owned by the active naming patch.
set -euo pipefail

just guard-positive \
  compiler/typechecker_brand_identity_test_entry.gst \
  phase19_brand_identity_authority

if [ ! -f compiler/phase19_spelling_rule.gst ]; then
  bash scripts/phase19_gust_name_list_removed_parity.sh
  echo "guard-cranelift-phase19-brand-authority-parity: ok (superseded rename transition, Level 2)"
  exit 0
fi

bash scripts/phase19_rename_invariance.sh

echo "guard-cranelift-phase19-brand-authority-parity: ok (record semantics and rename transition, Level 2)"
