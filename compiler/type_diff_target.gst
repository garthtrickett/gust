
            type Inner struct {
                val: int
            }
            type Outer struct {
                inner: Inner
            }
            type Option[T, ctx] enum {
                Some { val: T },
                None
            }
            func main() {
                mut ctx := os.Arena.New();
                defer ctx.Free();

                mut x: int := 42;
                mut o: Outer;
                o.inner.val = x;

                mut vec: std.Vector[Outer, ctx] := std.VectorNew(ctx);
                vec.Push(o);

                mut opt: Option[int, ctx];
                opt.tag = 0;
                opt.Some.val = 100;
            }
        