func main() {
    mut value := "Hello World";
    mut prefix := std.str_slice(value, 0, 5);
    os.LogStr(prefix);
    if std.str_eq(prefix, "Hello") {
        os.LogInt(1);
    } else {
        os.LogInt(0);
    }
    os.LogInt(std.str_byte_at(value, 6) as int);
    os.LogInt(999);
}
