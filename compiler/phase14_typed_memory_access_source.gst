// Phase 14.6 positive source marker. Canonical MIR records typed i32 stores
// and loads through compiler-owned stack-slot and non-null pointer origins.
func main() int {
    mut stack_value: int := 0;
    stack_value = 54;
    mut pointer_value: int := 0;
    pointer_value = 55;
    return stack_value + pointer_value - 55;
}