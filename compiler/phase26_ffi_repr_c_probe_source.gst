#[repr(C)]
type FfiProbe struct {
    a: byte,
    b: int,
    c: byte
}

extern func tiny_host_read_repr_c_probe(value: &FfiProbe #[ffi(borrow_read_call)]) int;

func main() int {
    mut value: FfiProbe;
    value.a = 1 as byte;
    value.b = 20;
    value.c = 3 as byte;
    unsafe {
        os.LogInt(tiny_host_read_repr_c_probe(&value));
    }
    return 0;
}
