type Inner[ctx] struct {
    ptr: *int,
    idx: Index[Inner, ctx]
}
type Outer[ctx] struct {
    inner: Inner[ctx]
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut o: Outer[ctx];
    if o.inner.ptr == empty[*int] {
        os.LogStr("ptr NULL ok");
    }
    if o.inner.idx == empty[Index[Inner, ctx]] {
        os.LogStr("idx null ok");
    }
}