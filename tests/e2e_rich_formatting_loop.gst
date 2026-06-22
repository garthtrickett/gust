func main() {
    mut i := 0;
    while i < 10 {
        mut s := std.Format("Index: %d", i);
        os.LogStr(s);
        os.ScratchReset();
        i = i + 1;
    } 
}
