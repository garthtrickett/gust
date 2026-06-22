func main() {
    mut name := "Gust";
    mut version := 1;
    mut s := std.Format("Welcome to %s version %d!", name, version);
    os.LogStr(s);
}
