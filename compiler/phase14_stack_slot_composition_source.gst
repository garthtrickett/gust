// Phase 14.5 composition marker: addressable locals compose with branches and
// supported loops while preserving deterministic slot identity and lifetime.
func main() int {
    mut value: int := 48;
    mut index: int := 0;
    while index < 5 {
        value = value + 1;
        index = index + 1;
    }
    if value == 53 {
        return value;
    }
    return 0;
}