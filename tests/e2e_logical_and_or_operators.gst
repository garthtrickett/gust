func evaluate_rhs(count: *int, return_val: bool) bool {
    unsafe {
        *count = *count + 1;
    }
    return return_val;
}
func main() {
    mut side_effect_count := 0;
    
    // Test 1: && short-circuiting
    mut r1 := false && evaluate_rhs(&side_effect_count, true);
    os.LogInt(side_effect_count);
    
    // Test 2: && non-short-circuiting
    mut r2 := true && evaluate_rhs(&side_effect_count, true);
    os.LogInt(side_effect_count);
    
    // Test 3: || short-circuiting
    mut r3 := true || evaluate_rhs(&side_effect_count, true);
    os.LogInt(side_effect_count);
    
    // Test 4: || non-short-circuiting
    mut r4 := false || evaluate_rhs(&side_effect_count, true);
    os.LogInt(side_effect_count);
    
    // Test 5: Combining operators with comparisons
    mut x := 10;
    mut y := 20;
    if x < 15 && y > 15 {
        os.LogInt(100);
    } else {
        os.LogInt(0);
    }
}