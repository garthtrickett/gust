// Future positive fixture: bool, i32, and i64 share compiler-owned target layouts.
func main() int {
    mut enabled: bool := true;
    mut small: int := 7;
    mut wide: int := 9;
    if enabled {
        return small + wide;
    }
    return 0;
}