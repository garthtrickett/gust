func main() int {
    mut value := 7;
    unsafe {
        mut pointer: *int := &value as *int;
    }
    return value;
}