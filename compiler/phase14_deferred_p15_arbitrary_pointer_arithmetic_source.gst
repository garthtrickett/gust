// Patch 14.13 current negative capability anchor.
// residual_id: p15_arbitrary_pointer_arithmetic
// capability: arbitrary_pointer_arithmetic
// expected_reason_code: deferred_p15_arbitrary_pointer_arithmetic
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }