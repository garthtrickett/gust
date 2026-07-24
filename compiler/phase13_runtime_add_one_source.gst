extern func tiny_host_add_one_i32(value: int) int;

func main() int {
    unsafe {
        return tiny_host_add_one_i32(41);
    }
}
