func leak_derived_raw_pointer(ptr: *int) *int {
    unsafe {
        mut next := ptr + 1;
        return next;
    }
}

func main() {
}