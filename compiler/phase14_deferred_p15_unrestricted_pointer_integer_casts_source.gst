// Patch 14.13 current negative capability anchor.
// residual_id: p15_unrestricted_pointer_integer_casts
// capability: unrestricted_pointer_integer_casts
// expected_reason_code: deferred_p15_unrestricted_pointer_integer_casts
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }