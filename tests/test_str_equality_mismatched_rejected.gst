// Compile-fail: '==' between str and int is a genuine type mismatch.
func main() {
    mut a: str := "abc";
    mut n := 3;
    if a == n {
        os.LogInt(1);
    } else {
        os.LogInt(0);
    }
}
