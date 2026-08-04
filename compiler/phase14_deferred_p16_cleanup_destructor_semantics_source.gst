// Patch 14.13 current negative capability anchor.
// residual_id: p16_cleanup_destructor_semantics
// capability: cleanup_and_destructor_semantics
// expected_reason_code: deferred_p16_cleanup_destructor_semantics
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }