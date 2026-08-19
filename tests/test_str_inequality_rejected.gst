// Compile-fail: str does not support '!=' — use std.str_eq.
func main() {
    mut a: str := "PING";
    mut b: str := "PONG";
    if a != b {
        os.LogStr("different");
    }
}
