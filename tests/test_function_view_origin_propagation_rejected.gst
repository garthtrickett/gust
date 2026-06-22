func choose_payload(cond: int, a: []byte, b: []byte) []byte {
    if cond {
        return a;
    } else {
        return b;
    }
}
func main() {
    mut p1 := os.MockPayload();
    mut p2 := os.MockPayload();
    mut result := choose_payload(1, p1, p2);
    mut moved := move p1;
    os.LogInt(result[0]);
}