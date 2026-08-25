# Cranelift Phase 21 Cross-Tenant Capability Boundary

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_cross_tenant_capability.py project`. Do not edit by hand.

- Contract: `phase21_cross_tenant_capability_v1`
- Status: `patch21_6_complete`
- Next patch: `21.7`
- Marker: `cross_tenant capability_expression`
- Host boundary: `cross_tenant_capability_from_host`
- Diagnostic: `CrossTenantCapability` — `error: cross_tenant requires a direct compiler-owned host capability at this query`

A deliberate cross-tenant query must spell the marker at that query
and directly invoke the reserved compile-time host capability. The marker
bypasses only that query's local scoped-root obligations. It cannot flow
through values, variables, helpers, returns, re-exports, or an outer query.

## Positive evidence

- `direct_cross_tenant_capability` — `compiler/phase21_cross_tenant_capability_positive.gst` — MIR-to-C exit `71`, Cranelift exit `71`
- `ordinary_scoped_query_unchanged` — `compiler/phase21_cross_tenant_ordinary_scoped_positive.gst` — MIR-to-C exit `72`, Cranelift exit `72`

## Rejection evidence

- `forged_value` — `compiler/phase21_cross_tenant_forged_invalid.gst` — `CrossTenantCapability`
- `ordinary_helper` — `compiler/phase21_cross_tenant_helper_invalid.gst` — `CrossTenantCapability`
- `reexport` — `compiler/phase21_cross_tenant_reexport_invalid.gst` — `CrossTenantCapabilityBoundary`
- `nested_nontransitive` — `compiler/phase21_cross_tenant_nested_nontransitive_invalid.gst` — `TenantScopeProvenance`
- `outside_marker` — `compiler/phase21_cross_tenant_outside_marker_invalid.gst` — `CrossTenantCapabilityBoundary`
- `reserved_redefinition` — `compiler/phase21_cross_tenant_redefinition_invalid.gst` — `ReservedCompilerIntrinsic`
- `wrong_arity` — `compiler/phase21_cross_tenant_wrong_arity_invalid.gst` — `CrossTenantCapability`

Privileged raw SQL remains a separate explicit unsafe boundary
outside the compiler-owned typed-query guarantee. This patch adds no
database runtime, broader effect system, MIR operation, ABI/layout,
runtime symbol, bootstrap seed, or Stdlib change. Establishment of
the trusted host capability remains outside the compiler claim.
