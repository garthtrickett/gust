// Phase 26.1D1: call-bounded read and raw-pointer write contracts typecheck.
// The external pointer parameters retain the Phase 13 native ABI deferral.
extern func ffi_host_borrow_read(value: str #[ffi(borrow_read_call)]);
extern func ffi_host_borrow_write(value: *int #[ffi(borrow_write_call)]);

func main() int {
    mut value := 3;
    unsafe {
        ffi_host_borrow_read("ffi borrowed");
        mut pointer: *int := &value as *int;
        ffi_host_borrow_write(pointer);
    }
    return 0;
}
