func advance_inside_unsafe(ptr: *int) *int {
    unsafe {
        mut next := ptr + 1;
        return next;
    }
}

func main() {
}