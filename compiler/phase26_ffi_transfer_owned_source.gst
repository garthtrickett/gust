#[repr(C)]
#[linear]
#[destructor(release_owned_int)]
#[opaque]
type OwnedInt struct { raw: *int }

#[repr(C)]
#[linear]
#[destructor(release_owned_byte)]
#[opaque]
type OwnedByte struct { raw: *byte }

extern func host_owned_int(value: int #[ffi(value)]) OwnedInt #[ffi(owned_return)];
extern func host_release_owned_int(raw: *int #[ffi(release_owned)]);
extern func host_take_owned_int(owner: OwnedInt #[ffi(transfer_owned)]);
extern func host_owned_byte() OwnedByte #[ffi(owned_return)];
extern func host_release_owned_byte(raw: *byte #[ffi(release_owned)]);
extern func host_take_owned_byte(owner: OwnedByte #[ffi(transfer_owned)]);

func release_owned_int(owner: OwnedInt) {
    unsafe { host_release_owned_int(owner.raw); }
}

func release_owned_byte(owner: OwnedByte) {
    unsafe { host_release_owned_byte(owner.raw); }
}

func early_transfer() int {
    unsafe {
        mut owner := host_owned_int(12);
        host_take_owned_int(owner);
        return 3;
    }
}

func deferred_transfer() {
    unsafe {
        mut owner := host_owned_byte();
        defer os.LogStr("defer_marker");
        host_take_owned_byte(owner);
    }
}

func main() int {
    unsafe {
        mut owner := host_owned_int(11);
        host_take_owned_int(owner);
    }
    os.LogInt(early_transfer());
    if 1 == 1 {
        deferred_transfer();
    }
    return 0;
}
