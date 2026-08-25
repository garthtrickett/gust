func main() {
    mut storage := os.Arena.New();
    defer storage.Free();
    os.SetThreadScratch(storage);

    mut numbers: std.Vector[int, storage] := std.VectorNew(storage);
    numbers.Push(7);
    numbers.Push(42);
    mut choice := numbers.get_opt(1);
    match choice {
        Some { val } => {
            unsafe { os.LogInt(*val); }
        }
        None => { os.LogStr("Missing"); }
    }
}
