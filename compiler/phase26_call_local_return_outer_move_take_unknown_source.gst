unsafe func make_unknown(value: *int) *int { return value; }
func safe_return() *int {
    unsafe { mut ptr := make_unknown(1 as *int); return move (take ptr); }
}
func main() int { return 0; }
