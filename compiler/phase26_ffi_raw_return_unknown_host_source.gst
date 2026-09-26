extern func tiny_host_unapproved_raw_int() *int #[ffi(raw_untrusted)];
func main() int { unsafe { mut raw := tiny_host_unapproved_raw_int(); os.LogInt(*raw); } return 0; }
