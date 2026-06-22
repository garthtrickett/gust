func main() {
    mut val := 42;
    mut ptr := &val;
    unsafe {
        mut deref := *ptr;
        os.LogInt(deref);
    }
}