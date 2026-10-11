unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay(ctx: &Arena) Index[int, ctx] {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut terminal := fourth; mut later := terminal; return later as Index[int, ctx]; }
}
func main() int { return 0; }
