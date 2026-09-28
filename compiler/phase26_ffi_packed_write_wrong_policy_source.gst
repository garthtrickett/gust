#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_write_packed_probe(value: *FfiProbe #[ffi(borrow_write_isolated_call)]);
func main() {
    mut value: FfiProbe;
    unsafe { mut pointer: *FfiProbe := &value as *FfiProbe; tiny_host_write_packed_probe(pointer); }
}
