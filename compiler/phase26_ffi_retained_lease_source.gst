#[repr(C)]
#[linear]
#[destructor(release_lease_int)]
#[opaque]
type LeaseInt struct {
    raw: *int
}

#[repr(C)]
#[linear]
#[destructor(release_lease_byte)]
#[opaque]
type LeaseByte struct {
    raw: *byte
}

extern func host_make_lease_int(value: int #[ffi(value)]) LeaseInt #[ffi(owned_return)];
extern func host_free_lease_int(raw: *int #[ffi(release_owned)]);
extern func host_register_lease_int(raw: *int #[ffi(retain)], marker: int #[ffi(value)]);

extern func host_make_lease_byte() LeaseByte #[ffi(owned_return)];
extern func host_free_lease_byte(raw: *byte #[ffi(release_owned)]);
extern func host_register_lease_byte(marker: int #[ffi(value)], raw: *byte #[ffi(retain)]);

func release_lease_int(owner: LeaseInt) {
    unsafe { host_free_lease_int(owner.raw); }
}

func release_lease_byte(owner: LeaseByte) {
    unsafe { host_free_lease_byte(owner.raw); }
}

func normal_route() {
    unsafe {
        mut owner := host_make_lease_int(41);
        host_register_lease_int(owner.raw, 1);
    }
}

func return_route() int {
    unsafe {
        mut owner := host_make_lease_byte();
        host_register_lease_byte(2, owner.raw);
        return 7;
    }
}

func guard_route() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    unsafe {
        mut owner := host_make_lease_byte();
        host_register_lease_byte(2, owner.raw);
        guard missing := values.Get(1) else {
            return 13;
        }
        os.LogInt(missing);
    }
    return 0;
}

func defer_route() {
    unsafe {
        mut owner := host_make_lease_int(41);
        host_register_lease_int(owner.raw, 1);
        defer os.LogStr("defer_marker");
    }
}

func main() int {
    normal_route();
    os.LogInt(return_route());
    os.LogInt(guard_route());
    defer_route();
    return 0;
}
