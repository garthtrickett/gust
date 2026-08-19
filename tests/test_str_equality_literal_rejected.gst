// Compile-fail: comparing a str against a literal is the shape real code hits.
func main() {
    mut command: str := "PING";
    if command == "PING" {
        os.LogStr("pong");
    }
}
