extern func tiny_host_raw_untrusted_int() *byte #[ffi(raw_untrusted)];
func main() int { unsafe { mut raw := tiny_host_raw_untrusted_int(); os.LogInt(*raw as int); } return 0; }
