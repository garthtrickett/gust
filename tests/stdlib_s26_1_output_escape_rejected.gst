import "../src/stdlib/native_bytes.gst" as native;
func escape_output(outer: &Arena) native.BytesResult[outer] {
    mut inner := os.Arena.New();
    defer inner.Free();
    mut input: std.Vector[byte, inner] := std.VectorNew(&inner);
    input.Push(3 as byte);
    return native.compress(&inner, &input, 64, 6);
}
func main() int { return 0; }
