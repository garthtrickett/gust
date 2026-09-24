// Reference parameters use the existing direct pointer ABI, but Reference
// returns remain outside the selected Phase 13 native source route.
func phase16_reference_return_deferred(value: &int) &int {
    return value;
}

func main() int {
    return 0;
}
