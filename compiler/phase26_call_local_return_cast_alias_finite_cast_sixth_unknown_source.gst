unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func relay() *int {
    unsafe { mut ptr := make_unknown(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut fifth := fourth as *int; mut sixth := fifth as *int; return sixth; }
}
func main() int { return 0; }
