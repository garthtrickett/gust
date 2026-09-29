func safe_return() *int {
    unsafe { return ((256 as byte) as int) as *int; }
}
func main() int { return 0; }
