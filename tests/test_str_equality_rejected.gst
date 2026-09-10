// Patch 24.2q repurposed: '==' on str is now content equality, so this
// fixture proves acceptance and the runtime result (was: rejection).
func main() {
    mut a: str := "PING";
    mut b: str := "PONG";
    if a == a {
        os.LogInt(101);
    } else {
        os.LogInt(100);
    }
    if a == b {
        os.LogInt(100);
    } else {
        os.LogInt(104);
    }
}
