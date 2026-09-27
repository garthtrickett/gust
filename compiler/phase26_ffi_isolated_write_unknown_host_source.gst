#[repr(C)]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_unknown_write(value: *FfiProbe #[ffi(borrow_write_isolated_call)]);
func main() int {
    mut value: FfiProbe;
    unsafe { mut pointer: *FfiProbe := &value as *FfiProbe; tiny_host_unknown_write(pointer); }
    return 0;
}
