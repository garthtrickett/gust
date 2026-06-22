func main() {
    mut i := 0;
    while i < 5 {
        mut s_num := std.FormatInt(i);
        mut greeting := std.Concat("Num: ", s_num);
        os.LogStr(greeting);
        os.ScratchReset();
        i = i + 1;
    }
}