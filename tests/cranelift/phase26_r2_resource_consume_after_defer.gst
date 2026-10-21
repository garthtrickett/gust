// Success-only feasibility witness for generic Resource-in-Val Guard/move/defer.
// The failure representation is tested separately; this file never constructs
// a failed result that still owns a real linear Handle.
#[linear]
#[destructor(release_handle)]
#[opaque]
type Handle struct { token: int }

type AcquireResult struct { Ok: int, Val: Handle, Code: int }

#[private]
func release_handle(handle: Handle) {
    os.LogInt(handle.token);
}

func acquire(token: int) AcquireResult {
    mut result: AcquireResult;
    result.Ok = 1;
    result.Code = 0;
    mut handle: Handle;
    handle.token = token;
    result.Val = move handle;
    return result;
}

func early_success() int {
    mut acquired := acquire(41);
    mut code: int := acquired.Code;
    guard handle := move acquired else {
        os.LogInt(code);
        return 19;
    }
    defer release_handle(handle);
    release_handle(move handle); // stale scheduled destructor must be denied
    return 42;
}

func normal_success() int {
    mut acquired := acquire(43);
    mut code: int := acquired.Code;
    guard handle := move acquired else {
        os.LogInt(code);
        return 19;
    }
    defer release_handle(handle);
    mut observed := handle.token + 1;
    return observed;
}

func main() int {
    os.LogInt(early_success());
    os.LogInt(normal_success());
    return 0;
}
