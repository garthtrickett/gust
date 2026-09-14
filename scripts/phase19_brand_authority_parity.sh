#!/usr/bin/env bash
# Phase 19 brand-authority parity: exercise the Patch 19.2 record.
#
# This harness used to carry a second half -- the rename-invariance
# transition -- by delegating to one of two other harnesses, selected on
# whether compiler/phase19_spelling_rule.gst exists. Patch 24.12a retired
# both of them: each compared the generated C of two spellings of the same
# standalone fixture, so what they proved was a property of the emitter being
# retired, not of the language. The record-semantics half below is this
# harness's own and is untouched.
#
# The delegation is removed rather than made conditional. A branch that
# silently skips a retired check would report ok having exercised nothing,
# and absence never counts as success.
set -euo pipefail

just guard-positive \
  compiler/typechecker_brand_identity_test_entry.gst \
  phase19_brand_identity_authority

echo "guard-cranelift-phase19-brand-authority-parity: ok (record semantics, Level 2)"
