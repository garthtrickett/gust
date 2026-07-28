// Phase 14.4 positive source inventory marker.
// Address creation, null construction, comparisons, null tests, and bounded
// nullability promotion are represented by compiler-owned canonical MIR kinds.
func main() int {
    mut addressable: int := 49;
    if addressable == 49 {
        return addressable;
    }
    return 0;
}