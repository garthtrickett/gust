#[repr(C)]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_unknown_aggregate(value: &FfiProbe #[ffi(borrow_read_call)]) int;
func main() int { mut value: FfiProbe; unsafe { return tiny_host_unknown_aggregate(&value); } }
