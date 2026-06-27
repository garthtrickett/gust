func main() {
    mut val := 42;
    unsafe {
        mut ptr: *int := &val as *int;
    }
}