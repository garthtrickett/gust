extern func tiny_host_add_one_i32(value: int) int;

func main() int {
    unsafe {
        mut result := tiny_host_add_one_i32(39);
        result = tiny_host_add_one_i32(result);
        return result + 1;
    }
}