extern func ffi_host_borrow_read(value: str #[ffi(borrow_read_call)]);

func main() int {
    ffi_host_borrow_read("unsafe required");
    return 0;
}
