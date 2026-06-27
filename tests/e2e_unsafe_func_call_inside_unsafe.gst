unsafe func read_raw(ptr: *int) int {
    mut got := *ptr;
    return got;
}

func main() {
    mut val := 42;
    unsafe {
        mut ptr: *int := &val as *int;
        mut got := read_raw(ptr);
        os.LogInt(got);
    }
}