#[repr(C)]
type FfiProbe struct { c: byte, b: int, a: byte }
extern func tiny_host_read_repr_c_probe(value: &FfiProbe #[ffi(borrow_read_call)]) int;
func main() int { mut value: FfiProbe; unsafe { return tiny_host_read_repr_c_probe(&value); } }
