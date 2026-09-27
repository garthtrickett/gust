extern func tiny_host_write_repr_c_probe(value: *int #[ffi(borrow_write_isolated_call)]);

func main() int {
    mut value := 20;
    unsafe {
        mut pointer: *int := &value as *int;
        tiny_host_write_repr_c_probe(pointer);
    }
    return 0;
}
