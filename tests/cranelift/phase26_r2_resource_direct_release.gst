#[linear]
#[destructor(release_handle)]
#[opaque]
type Handle struct { token: int }

type AcquireResult struct { Ok: int, Val: Handle, Code: int }

#[private]
func release_handle(handle: Handle) { os.LogInt(handle.token); }

func acquire(token: int) AcquireResult {
    mut result: AcquireResult;
    result.Ok = 1;
    result.Code = 0;
    mut handle: Handle;
    handle.token = token;
    result.Val = move handle;
    return result;
}

func main() int {
    mut acquired := acquire(41);
    guard handle := move acquired else { return 19; }
    release_handle(move handle); // live owner is consumed exactly once
    defer os.LogInt(7); // unrelated deferred scalar call; owner is already consumed
    os.LogInt(42);
    return 0;
}
