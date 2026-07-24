extern func tiny_host_add_i32(left: int, right: int) int;

func lift(value: int) int {
    unsafe {
        return tiny_host_add_i32(value, 2);
    }
}
