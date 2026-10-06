#[repr(C)]
type DirectAlpha struct {
    lead: byte,
    tail: byte,
    tally: int
}

#[repr(C)]
#[packed]
type DirectBeta struct {
    count: int,
    flag: byte
}

extern func host_direct_alpha(read: &DirectAlpha #[ffi(borrow_read_call)], write: *DirectBeta #[ffi(borrow_write_call)], bonus: int #[ffi(value)]) int;
extern func host_direct_beta(read: &DirectBeta #[ffi(borrow_read_call)], write: *DirectAlpha #[ffi(borrow_write_call)], bonus: int #[ffi(value)]) int;

func early_return_call() int {
    mut alpha: DirectAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: DirectBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        return host_direct_alpha(&alpha, &beta as *DirectBeta, 4);
    }
}

func guard_after_call() int {
    mut alpha: DirectAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: DirectBeta;
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        os.LogInt(host_direct_beta(&beta, &alpha as *DirectAlpha, 2));
        os.LogInt(alpha.tally);
        guard missing := values.Get(1) else {
            return 13;
        }
        os.LogInt(missing);
    }
    return 0;
}

func defer_after_call() {
    mut alpha: DirectAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: DirectBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        defer os.LogStr("direct_defer_marker");
        os.LogInt(host_direct_alpha(&alpha, &beta as *DirectBeta, 4));
        os.LogInt(beta.count);
    }
}

func main() int {
    mut alpha: DirectAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: DirectBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        os.LogInt(host_direct_alpha(&alpha, &beta as *DirectBeta, 4));
        os.LogInt(alpha.lead as int);
        os.LogInt(beta.count);
        os.LogInt(beta.flag as int);
        os.LogInt(host_direct_beta(&beta, &alpha as *DirectAlpha, 2));
        os.LogInt(beta.flag as int);
        os.LogInt(alpha.tally);
        os.LogInt(alpha.tail as int);
    }
    os.LogInt(early_return_call());
    os.LogInt(guard_after_call());
    defer_after_call();
    return 0;
}
