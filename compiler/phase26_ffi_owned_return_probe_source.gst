#[repr(C)]
#[linear]
#[destructor(release_owned_int)]
#[opaque]
type OwnedInt struct {
    raw: *int
}

extern func host_owned_int(value: int #[ffi(value)]) OwnedInt #[ffi(owned_return)];
extern func host_release_owned_int(raw: *int #[ffi(release_owned)]);

func release_owned_int(owner: OwnedInt) {
    unsafe { host_release_owned_int(owner.raw); }
}

func main() int {
    unsafe {
        mut owner := host_owned_int(1);
    }
    return 0;
}
