// A scalar-derived raw address cannot become a safe branded arena index.
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    unsafe {
        mut raw := 0 as *int;
        mut forged: Index[int, ctx] := raw as Index[int, ctx];
        os.LogInt(1);
    }
}
