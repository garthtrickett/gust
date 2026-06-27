func main() {
    mut val := 42;
    unsafe {
        mut ptr: *int := &val as *int;
        mut same := ptr + 0;
        mut got := *same;
        os.LogInt(got);
    }
}
