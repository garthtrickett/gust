unsafe func unsafe_add_one(x: int) int {
    return x + 1;
}

func main() {
    unsafe {
        mut got := unsafe_add_one(41);
        if got != 42 {
            os.Exit(1);
        }
    }
}
