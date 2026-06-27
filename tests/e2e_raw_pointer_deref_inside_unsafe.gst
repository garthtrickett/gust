func main() {
    mut val := 42;
    unsafe {
        mut ptr: *int := &val as *int;
        mut got := *ptr;
        os.LogInt(got);
    }
}