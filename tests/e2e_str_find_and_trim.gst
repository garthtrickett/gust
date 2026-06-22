func main() {
    mut s := "  hello  ";
    mut trimmed := std.str_trim(s);
    os.LogStr(trimmed);

    mut idx1 := std.str_find(trimmed, "ll");
    os.LogInt(idx1);

    mut idx2 := std.str_find(trimmed, "xx");
    os.LogInt(idx2);
}