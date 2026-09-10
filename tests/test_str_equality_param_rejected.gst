// Patch 24.2q repurposed: '==' through function parameters compares
// content, so this fixture proves acceptance across calls
// (was: rejection).
func eq2(x: str, y: str) int {
    if x == y {
        return 1;
    }
    return 0;
}
func main() {
    mut a: str := "PING";
    if eq2(a, "PING") == 1 {
        os.LogInt(108);
    } else {
        os.LogInt(100);
    }
    if eq2(a, "PONG") == 1 {
        os.LogInt(100);
    } else {
        os.LogInt(109);
    }
}
