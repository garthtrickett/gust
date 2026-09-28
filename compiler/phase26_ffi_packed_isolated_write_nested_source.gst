#[repr(C)]
#[packed]
#[repr(C)]
type Inner struct { x: int }
type FfiProbe struct { a: byte, b: Inner, c: byte }
extern func tiny_host_write_packed_probe(value: *FfiProbe #[ffi(borrow_write_isolated_call)]);
func main() int {
    mut value: FfiProbe;
    unsafe {
        mut pointer: *FfiProbe := &value as *FfiProbe;
        tiny_host_write_packed_probe(pointer);
    }
    return 0;
}
