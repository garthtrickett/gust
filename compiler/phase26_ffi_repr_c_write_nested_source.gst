#[repr(C)]
type FfiNested struct { x: int }
#[repr(C)]
type FfiProbe struct { a: byte, b: int, c: byte, d: FfiNested }
extern func tiny_host_write_repr_c_probe(value: *FfiProbe #[ffi(borrow_write_call)]);
func main() int {
    mut value: FfiProbe;
    unsafe { mut pointer: *FfiProbe := &value as *FfiProbe; tiny_host_write_repr_c_probe(pointer); }
    return 0;
}
