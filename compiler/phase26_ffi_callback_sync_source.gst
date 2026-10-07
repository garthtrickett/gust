extern func host_apply_alpha(callback: Callback[int, int] #[ffi(callback)], bias: int #[ffi(value)]) int;
extern func host_apply_beta(bias: int #[ffi(value)], callback: Callback[int, int] #[ffi(callback)], scale: int #[ffi(value)]) int;

func callback_add_three(value: int) int {
    return value + 3;
}

func callback_double(value: int) int {
    return value * 2;
}

func early_callback() int {
    unsafe {
        return host_apply_alpha(callback_add_three, 4);
    }
}

func main() int {
    unsafe {
        os.LogInt(host_apply_alpha(callback_add_three, 4));
        os.LogInt(host_apply_beta(5, callback_double, 3));
        os.LogInt(early_callback());
    }
    return 0;
}
