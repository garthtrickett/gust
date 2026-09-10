// Positive: '==' and '!=' on str compare content, not view identity.
func main() {
    mut a: str := "abc";
    mut b: str := "abc";
    mut c: str := "abd";
    mut d: str := "";
    mut e: str := "";
    // Equal content at different addresses: a slice view over a longer
    // literal lives elsewhere in memory but must still compare equal.
    mut f: str := std.str_slice("xabc", 1, 4);
    if a == b {
        os.LogInt(101);
    } else {
        os.LogInt(100);
    }
    if a != c {
        os.LogInt(102);
    } else {
        os.LogInt(100);
    }
    if d == e {
        os.LogInt(103);
    } else {
        os.LogInt(100);
    }
    if a == c {
        os.LogInt(100);
    } else {
        os.LogInt(104);
    }
    if a == f {
        os.LogInt(105);
    } else {
        os.LogInt(100);
    }
    if f != b {
        os.LogInt(100);
    } else {
        os.LogInt(106);
    }
}
