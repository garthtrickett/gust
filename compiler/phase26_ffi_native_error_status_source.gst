extern func host_status_alpha(selector: int #[ffi(value)]) int #[ffi(native_error)];
extern func host_status_beta(selector: int #[ffi(value)]) int #[ffi(native_error)];
extern func host_status_zero_arg() int #[ffi(native_error)];

func main() int {
    unsafe {
        os.LogInt(host_status_alpha(0));
        os.LogInt(host_status_alpha(1));
        os.LogInt(host_status_alpha(2));
        os.LogInt(host_status_alpha(3));
        os.LogInt(host_status_alpha(4));
        os.LogInt(host_status_beta(0));
        os.LogInt(host_status_beta(1));
        os.LogInt(host_status_beta(2));
        os.LogInt(host_status_beta(3));
        os.LogInt(host_status_beta(4));
        os.LogInt(host_status_zero_arg());
    }
    return 0;
}
