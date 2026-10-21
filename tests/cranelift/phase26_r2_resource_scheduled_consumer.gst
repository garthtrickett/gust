#[linear]
#[destructor(release_handle)]
#[opaque]
type Handle struct { token: int }

type AcquireResult struct { Ok: int, Val: Handle, Code: int }

#[private]
func release_handle(handle: Handle) { os.LogInt(handle.token); }

#[private]
func consume_handle(handle: Handle) { os.LogInt(handle.token); }

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
    defer release_handle(handle);
    consume_handle(move handle); // must reject non-live acquisition
    return 0;
}
