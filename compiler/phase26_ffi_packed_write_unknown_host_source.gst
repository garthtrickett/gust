#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_unknown_packed_write(value: *FfiProbe #[ffi(borrow_write_call)]);
func main() {
    mut value: FfiProbe;
    unsafe { mut pointer: *FfiProbe := &value as *FfiProbe; tiny_host_unknown_packed_write(pointer); }
}
