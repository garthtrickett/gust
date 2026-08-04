// Patch 14.13 current negative capability anchor.
// residual_id: p15_vector_simd_layout
// capability: vector_and_SIMD_layout
// expected_reason_code: deferred_p15_vector_simd_layout
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }