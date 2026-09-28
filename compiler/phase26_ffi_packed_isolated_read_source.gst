#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_read_packed_probe(value: &FfiProbe #[ffi(borrow_read_isolated_call)]) int;

func main() int {
    mut value: FfiProbe;
    unsafe {
        value.a = 1 as byte;
        value.b = 20;
        value.c = 3 as byte;
        os.LogInt(tiny_host_read_packed_probe(&value));
        os.LogInt(value.b);
    }
    return 0;
}
