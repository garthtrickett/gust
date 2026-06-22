func main() {
    mut x := 10 + 20 * 2;
    os.LogInt(x);

    if x == 50 {
        os.LogInt(1);
    } else {
        os.LogInt(0);
    }
}
