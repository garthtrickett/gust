#[repr(C)]
type IsolatedAlpha struct {
    lead: byte,
    tail: byte,
    tally: int
}

#[repr(C)]
#[packed]
type IsolatedBeta struct {
    count: int,
    flag: byte
}

extern func host_isolated_alpha(read: &IsolatedAlpha #[ffi(borrow_read_isolated_call)], write: *IsolatedBeta #[ffi(borrow_write_isolated_call)], bonus: int #[ffi(value)]) int;
extern func host_isolated_beta(read: &IsolatedBeta #[ffi(borrow_read_isolated_call)], write: *IsolatedAlpha #[ffi(borrow_write_isolated_call)], bonus: int #[ffi(value)]) int;

func early_return_call() int {
    mut alpha: IsolatedAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: IsolatedBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        mut beta_pointer: *IsolatedBeta := &beta as *IsolatedBeta;
        return host_isolated_alpha(&alpha, beta_pointer, 4);
    }
}

func guard_after_call() int {
    mut alpha: IsolatedAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: IsolatedBeta;
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        mut alpha_pointer: *IsolatedAlpha := &alpha as *IsolatedAlpha;
        os.LogInt(host_isolated_beta(&beta, alpha_pointer, 2));
        guard missing := values.Get(1) else {
            return 13;
        }
        os.LogInt(missing);
    }
    return 0;
}

func defer_after_call() {
    mut alpha: IsolatedAlpha;
    alpha.lead = 1 as byte;
    alpha.tail = 3 as byte;
    alpha.tally = 20;
    mut beta: IsolatedBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        mut beta_pointer: *IsolatedBeta := &beta as *IsolatedBeta;
        defer os.LogStr("isolated_defer_marker");
        os.LogInt(host_isolated_alpha(&alpha, beta_pointer, 4));
    }
}

func main() int {
    mut alpha: IsolatedAlpha;
    alpha.lead = 1 as byte;
    alpha.tally = 20;
    alpha.tail = 3 as byte;
    mut beta: IsolatedBeta;
    unsafe {
        beta.count = 5;
        beta.flag = 2 as byte;
        mut beta_pointer: *IsolatedBeta := &beta as *IsolatedBeta;
        os.LogInt(host_isolated_alpha(&alpha, beta_pointer, 4));
        os.LogInt(alpha.lead as int);
        os.LogInt(beta.count);
        os.LogInt(beta.flag as int);
        mut alpha_pointer: *IsolatedAlpha := &alpha as *IsolatedAlpha;
        os.LogInt(host_isolated_beta(&beta, alpha_pointer, 2));
        os.LogInt(beta.flag as int);
        os.LogInt(alpha.tally);
        os.LogInt(alpha.tail as int);
    }
    os.LogInt(early_return_call());
    os.LogInt(guard_after_call());
    defer_after_call();
    return 0;
}
