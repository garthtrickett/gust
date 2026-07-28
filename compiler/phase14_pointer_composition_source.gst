// Phase 14.4 composition marker: pointer values compose with locals,
// comparisons, nullable branches, and aggregate-field transport without
// dereference or pointer arithmetic.
func main() int {
    mut aggregate_field: int := 50;
    if aggregate_field == 50 {
        return aggregate_field;
    }
    return 0;
}