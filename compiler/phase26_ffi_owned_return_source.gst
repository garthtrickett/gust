#[repr(C)]
#[linear]
#[destructor(release_owned_int)]
#[opaque]
type OwnedInt struct {
    raw: *int
}

#[repr(C)]
#[linear]
#[destructor(release_owned_byte)]
#[opaque]
type OwnedByte struct {
    raw: *byte
}

extern func host_owned_int(value: int #[ffi(value)]) OwnedInt #[ffi(owned_return)];
extern func host_release_owned_int(raw: *int #[ffi(release_owned)]);
extern func host_owned_byte() OwnedByte #[ffi(owned_return)];
extern func host_release_owned_byte(raw: *byte #[ffi(release_owned)]);

func release_owned_int(owner: OwnedInt) {
    unsafe { host_release_owned_int(owner.raw); }
}

func release_owned_byte(owner: OwnedByte) {
    unsafe { host_release_owned_byte(owner.raw); }
}

func early_return_cleanup() int {
    unsafe {
        mut owner := host_owned_int(42);
        os.LogInt(*owner.raw);
        return 12;
    }
}

func guard_cleanup() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    unsafe {
        mut owner := host_owned_byte();
        guard missing := values.Get(1) else {
            return 13;
        }
        os.LogInt(missing);
        os.LogInt(*owner.raw as int);
    }
    return 0;
}

func defer_cleanup() {
    unsafe {
        mut owner := host_owned_int(43);
        defer os.LogStr("defer_marker");
        os.LogInt(*owner.raw);
    }
}

func transfer_owner() OwnedInt {
    unsafe {
        mut owner := host_owned_int(44);
        return owner;
    }
}

func main() int {
    unsafe {
        mut int_owner := host_owned_int(41);
        mut byte_owner := host_owned_byte();
        os.LogInt(*int_owner.raw);
        os.LogInt(*byte_owner.raw as int);
    }
    os.LogInt(early_return_cleanup());
    os.LogInt(guard_cleanup());
    defer_cleanup();
    unsafe {
        mut transferred := transfer_owner();
        os.LogInt(*transferred.raw);
    }
    return 0;
}
