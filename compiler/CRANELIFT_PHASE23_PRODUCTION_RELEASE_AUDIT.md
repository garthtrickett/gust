# Cranelift Phase 23.12 — Production, Release, Package, and Downstream Audit

Generated from the canonical feature registry. Do not edit by hand.

- Contract: `phase23_production_release_audit_v1`
- Status: `patch23_12_complete`
- Next patch: `23.13`
- Supported surfaces: `6`
- Supported surface manifest: `e33455dae7d0d52c7d585256c3a485b2af96543c7551275c400e0ea9d0d419d4`
- Repository compiler invocations: `318`
- Retained explicit-C call sites: `178`
- Phase 25 bootstrap explicit-C call sites: `5`
- Non-production historical/test call sites: `173`
- Supported production/release explicit-C calls: `0`
- Active non-bootstrap live-C lanes: `1`
- Active live-C owner: `phase23_mir_to_c_focused_live`
- Unknown registered downstream consumers: `0`

The remaining historical and archived call sites are retained evidence, not
supported production or release routes. The only live non-bootstrap C owner
is the Patch 23.10 focused oracle lane; bootstrap remains owned by Phase 25.
Explicit C remains deprecated and available through Phase 23. Phase 24 removes
the backend route; Phase 25 separately removes bootstrap C. Repository-wide C
absence is not claimed.
