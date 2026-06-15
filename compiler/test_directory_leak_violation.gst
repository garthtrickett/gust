func leak_dir(ctx: &Arena) {
    mut d: os.Dir[ctx];
    // forgot to call os.CloseDir(d);
}

func main() {}
