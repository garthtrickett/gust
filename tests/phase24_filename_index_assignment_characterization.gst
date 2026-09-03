func main() {
    mut source := "alpha";
    mut view := source;
    source = "beta";
    os.LogInt(len(source));
}
