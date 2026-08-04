// Patch 14.13 current negative capability anchor.
// residual_id: p15_trait_object_fat_pointers
// capability: trait_object_and_other_fat_pointers
// expected_reason_code: deferred_p15_trait_object_fat_pointers
// This marker freezes current ownership; the destination phase owns executable diagnostics.
func main() int { return 14; }