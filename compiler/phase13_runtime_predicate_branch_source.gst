extern func tiny_host_is_positive_i32(value: int) int;

func main() int {
    unsafe {
        mut predicate := tiny_host_is_positive_i32(7);
        if predicate > 0 {
            return 42;
        }
        return 7;
    }
}
