// Phase 14.5 positive aggregate marker. The canonical stack-slot table owns a
// bounded two-i32 aggregate layout and copy; this source remains intentionally
// simple so the source route does not infer aggregate layout from names.
func main() int {
    mut first: int := 50;
    mut second: int := 51;
    return first + second;
}