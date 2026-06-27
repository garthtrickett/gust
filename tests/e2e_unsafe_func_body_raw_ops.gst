unsafe func raw_body_ops(value: int) int {
    mut ptr: *int := &value as *int;
    mut same := ptr + 0;
    mut got := *same;
    return got;
}

func main() {
    unsafe {
        mut got := raw_body_ops(42);
        os.LogInt(got);
    }
}