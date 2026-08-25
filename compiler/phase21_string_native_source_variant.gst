func main() {
    mut text := "Native Route";
    mut leading := std.str_slice(text, 0, 6);
    os.LogStr(leading);
    if std.str_eq(leading, "Native") {
        os.LogInt(7);
    } else {
        os.LogInt(9);
    }
    os.LogInt(std.str_byte_at(text, 7) as int);
}
