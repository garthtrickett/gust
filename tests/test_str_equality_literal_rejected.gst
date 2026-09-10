// Patch 24.2q repurposed: literal and slice views compare by content,
// so this fixture proves acceptance including distinct addresses
// (was: rejection).
func main() {
    mut d: str := "";
    mut e: str := "";
    mut f: str := std.str_slice("xabc", 1, 4);
    if d == e {
        os.LogInt(103);
    } else {
        os.LogInt(100);
    }
    if f == "abc" {
        os.LogInt(105);
    } else {
        os.LogInt(100);
    }
}
