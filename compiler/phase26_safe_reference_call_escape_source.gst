func consume(value: &int) {
    os.LogInt(1);
}

func main() {
    unsafe {
        mut raw := 0 as *int;
        mut local_ref: &int := raw as & &int;
        consume(local_ref);
    }
}
