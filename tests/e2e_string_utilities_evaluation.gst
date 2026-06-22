func main() {
    mut s := "Hello World";
    
    // Substring slice
    mut sub := std.str_slice(s, 0, 5);
    os.LogStr(sub);
    
    // Substring slice 2
    mut sub2 := std.str_slice(s, 6, 11);
    os.LogStr(sub2);

    // Equality checks
    if std.str_eq(sub, "Hello") {
        os.LogInt(1);
    } else {
        os.LogInt(0);
    }

    if std.str_eq(sub, sub2) {
        os.LogInt(1);
    } else {
        os.LogInt(0);
    }

    // Safe index byte retrieval
    mut b := std.str_byte_at(s, 6);
    os.LogInt(b as int);
}