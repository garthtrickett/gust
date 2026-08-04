// Patch 14.13 current negative capability anchor.
// residual_id: p16_volatile_memory
// capability: volatile_memory_operations
// expected_reason_code: deferred_p16_volatile_memory
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }