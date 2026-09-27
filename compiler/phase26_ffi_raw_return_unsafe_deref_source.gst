extern func tiny_host_raw_untrusted_int() *int #[ffi(raw_untrusted)];
func main() int { mut raw: *int; unsafe { raw = tiny_host_raw_untrusted_int(); } return *raw; }
