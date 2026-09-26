#[repr(C)]
type FfiNested struct { x: int }
#[repr(C)]
type FfiProbe struct { a: byte, b: int, c: byte, d: FfiNested }
extern func tiny_host_read_repr_c_probe(value: &FfiProbe #[ffi(borrow_read_call)]) int;
func main() int { mut value: FfiProbe; unsafe { return tiny_host_read_repr_c_probe(&value); } }
