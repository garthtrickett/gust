#[repr(int)] type Status enum { Zero, One }

extern func tiny_host_echo_repr_int(value: Status #[ffi(value)]) Status #[ffi(value)];

func choose(value: Status) Status {
    return value;
}

func main() int {
    mut value: Status;
    unsafe { value.tag = 1; }
    mut chosen := choose(value);
    unsafe { chosen = tiny_host_echo_repr_int(chosen); }
    match chosen {
        Zero => { return 1; }
        One => { return 42; }
    }
}
