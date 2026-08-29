#!/usr/bin/env bash
set -euo pipefail

# Keep the Phase 10 packaging/help evidence in its historical shard. Once the
# registered Phase 22 default flip exists, replay its live default-native and
# explicit-C rollback evidence after that package has been built.
just guard-cranelift-phase10-packaging-help-ci
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  just guard-cranelift-phase22-default-route-flip-evidence
  just guard-cranelift-phase22-postflip-qualification-evidence
fi
