#[repr(C)]
type Inner struct { x: int }
#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: Inner, c: byte }
extern func tiny_host_read_packed_probe(value: &FfiProbe #[ffi(borrow_read_isolated_call)]) int;
func main() int { mut value: FfiProbe; unsafe { return tiny_host_read_packed_probe(&value); } }
