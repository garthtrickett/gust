func leak() &int {
    unsafe {
        mut raw := 0 as *int;
        mut local_ref: &int := raw as & &int;
        return local_ref;
    }
}
func main() {}
