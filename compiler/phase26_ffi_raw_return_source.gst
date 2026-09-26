extern func tiny_host_raw_untrusted_int() *int #[ffi(raw_untrusted)];

func main() int {
    unsafe {
        mut raw: *int := tiny_host_raw_untrusted_int();
        os.LogInt(*raw);
    }
    return 0;
}
