#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_write_packed_probe(value: *FfiProbe #[ffi(borrow_write_call)]);

func main() int {
    mut value: FfiProbe;
    unsafe {
        value.a = 1 as byte;
        value.b = 20;
        value.c = 3 as byte;
        os.LogInt(value.b);
        mut pointer: *FfiProbe := &value as *FfiProbe;
        tiny_host_write_packed_probe(pointer);
        os.LogInt(value.b);
        os.LogInt(value.c as int);
    }
    return 0;
}
