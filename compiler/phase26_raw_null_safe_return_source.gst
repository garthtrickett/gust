func safe_zero() *int {
    unsafe {
        mut raw := 0 as *int;
        return raw;
    }
}
func main() int { return 0; }
