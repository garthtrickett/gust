func raw_policy_without_extern() *int #[ffi(raw_untrusted)] {
    unsafe { return 0 as *int; }
}
func main() int { return 0; }
