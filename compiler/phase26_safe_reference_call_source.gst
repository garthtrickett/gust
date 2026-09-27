func read_value(value: &int) {
    unsafe { os.LogInt(*value); }
}

unsafe func accept_untrusted(value: &int) {
    os.LogInt(7);
}

func main() {
    mut number := 42;
    mut safe_ref: &int := &number;
    read_value(safe_ref);
    unsafe {
        mut raw := 0 as *int;
        mut local_ref: &int := raw as & &int;
        accept_untrusted(local_ref);
    }
}
