#[repr(C)]
#[packed]
type FfiProbe struct { a: byte, b: int, c: byte }
extern func tiny_host_read_packed_probe(value: FfiProbe);
func main() { mut value: FfiProbe; unsafe { tiny_host_read_packed_probe(value); } }
