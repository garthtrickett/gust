func main() {
    mut scratch := os.Arena.New();
    defer scratch.Free();
    mut target := "phase21-filesystem-variant.txt";
    mut success := os.WriteFile(target, "phase21");
    os.LogInt(success);
    mut payload := os.ReadFile(scratch, target);
    os.LogStr(payload);
}
