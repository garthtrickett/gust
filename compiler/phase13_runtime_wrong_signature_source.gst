extern func tiny_host_add_i32(left: int) int;

func main() int {
    unsafe {
        return tiny_host_add_i32(42);
    }
}
