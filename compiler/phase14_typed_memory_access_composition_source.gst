// Phase 14.6 composition marker. A bounded two-i32 aggregate uses the
// compiler-selected i32 stride for its second-element offset and non-overlap
// copy while scalar stack and pointer accesses remain active.
func main() int {
    mut first: int := 50;
    mut second: int := first;
    if second == 50 {
        return 56;
    }
    return 0;
}