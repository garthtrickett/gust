// Patch 14.13 current negative capability anchor.
// residual_id: p16_dynamic_stack_allocation
// capability: dynamic_stack_allocation
// expected_reason_code: deferred_p16_dynamic_stack_allocation
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }