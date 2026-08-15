// Migrated composition source: aggregate return-to-parameter transport crosses
// a direct call while the canonical composition plan supplies typed-indirect,
// fat-pointer, dynamic-frame, resource, and cross-module witnesses.
// migrated_by: phase16.13_cross_feature_abi_composition
type Phase16CompositionPair struct { left: int, right: int }
func phase16_composition_make() Phase16CompositionPair { mut value: Phase16CompositionPair; value.left = 7; value.right = 9; return value; }
func phase16_composition_consume(value: Phase16CompositionPair) int { return value.left + value.right; }
func main() {
    mut value := phase16_composition_consume(phase16_composition_make());
    if value != 16 { os.Exit(1); }
    os.LogStr("SUCCESS: Phase 16.13 composed ABI source passed");
}
