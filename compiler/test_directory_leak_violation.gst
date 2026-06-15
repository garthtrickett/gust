func leak_dir(ctx: &Arena) {
    mut opt_dir := os.OpenDir(ctx, "src");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        // forgot to call os.CloseDir(d);
    }
}

func main() {}