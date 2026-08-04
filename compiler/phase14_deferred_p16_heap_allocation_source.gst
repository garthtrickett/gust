// Patch 14.13 current negative capability anchor.
// residual_id: p16_heap_allocation
// capability: heap_allocation
// expected_reason_code: deferred_p16_heap_allocation
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }