// Patch 24.2q repurposed: '!=' on str is now content inequality, so this
// fixture proves acceptance and the runtime result (was: rejection).
func main() {
    mut a: str := "PING";
    mut b: str := "PONG";
    if a != b {
        os.LogInt(102);
    } else {
        os.LogInt(100);
    }
    if b != b {
        os.LogInt(100);
    } else {
        os.LogInt(107);
    }
}
