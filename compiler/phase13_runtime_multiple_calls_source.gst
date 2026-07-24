extern func tiny_host_add_one_i32(value: int) int;

func main() int {
    unsafe {
        mut result := tiny_host_add_one_i32(40);
        result = tiny_host_add_one_i32(result);
        return result + 0;
    }
}
