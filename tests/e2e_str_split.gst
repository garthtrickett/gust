func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut s := "a,b,c,d";
    mut parts := std.str_split(s, ",", ctx);
    os.LogInt(len(parts));
    os.LogStr(parts[0]);
    os.LogStr(parts[1]);
    os.LogStr(parts[2]);
    os.LogStr(parts[3]);

    mut s2 := "xyz";
    mut parts2 := std.str_split(s2, "", ctx);
    os.LogInt(len(parts2));
    os.LogStr(parts2[0]);
    os.LogStr(parts2[1]);
    os.LogStr(parts2[2]);

    mut parts3 := std.str_split(s, "x", ctx);
    os.LogInt(len(parts3));
    os.LogStr(parts3[0]);
}