#[repr(C)]
type VectorAlpha struct {
    amount: int,
    flag: byte
}

#[repr(C)]
#[packed]
type VectorBeta struct {
    amount: int,
    marker: byte
}

extern func host_vector_alpha(direct_read: &VectorAlpha #[ffi(borrow_read_call)], isolated_read: &VectorBeta #[ffi(borrow_read_isolated_call)], direct_write: *VectorAlpha #[ffi(borrow_write_call)], isolated_write: *VectorBeta #[ffi(borrow_write_isolated_call)], selector: int #[ffi(value)]) int #[ffi(native_error)];
extern func host_vector_beta(direct_read: &VectorBeta #[ffi(borrow_read_call)], isolated_read: &VectorAlpha #[ffi(borrow_read_isolated_call)], direct_write: *VectorBeta #[ffi(borrow_write_call)], isolated_write: *VectorAlpha #[ffi(borrow_write_isolated_call)], selector: int #[ffi(value)]) int #[ffi(native_error)];
extern func host_vector_alias_pair(direct_read: &VectorAlpha #[ffi(borrow_read_call)], isolated_read: &VectorAlpha #[ffi(borrow_read_isolated_call)]) int #[ffi(native_error)];
extern func host_vector_scalar_mix(direct_read: &VectorAlpha #[ffi(borrow_read_call)], isolated_read: &VectorAlpha #[ffi(borrow_read_isolated_call)], byte_value: byte #[ffi(value)], bool_value: bool #[ffi(value)]) int #[ffi(native_error)];
extern func host_vector_direct_only(direct_read: &VectorAlpha #[ffi(borrow_read_call)], direct_write: *VectorBeta #[ffi(borrow_write_call)], selector: int #[ffi(value)]) int #[ffi(native_error)];

func direct_only_status() int {
    mut direct_alpha: VectorAlpha;
    direct_alpha.amount = 10;
    direct_alpha.flag = 2 as byte;
    mut written_beta: VectorBeta;
    unsafe {
        written_beta.amount = 0;
        written_beta.marker = 0 as byte;
        mut status := host_vector_direct_only(&direct_alpha, &written_beta as *VectorBeta, 2);
        os.LogInt(written_beta.amount);
        return status;
    }
}

func return_after_status() int {
    mut direct_alpha: VectorAlpha;
    direct_alpha.amount = 10;
    direct_alpha.flag = 2 as byte;
    mut isolated_beta: VectorBeta;
    mut written_alpha: VectorAlpha;
    mut written_beta: VectorBeta;
    unsafe {
        isolated_beta.amount = 5;
        isolated_beta.marker = 3 as byte;
        written_alpha.amount = 0;
        written_alpha.flag = 0 as byte;
        written_beta.amount = 0;
        written_beta.marker = 0 as byte;
        mut status := host_vector_alpha(&direct_alpha, &isolated_beta,
            &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 1);
        return status + written_alpha.amount + written_beta.amount;
    }
}

func guard_after_status() int {
    mut direct_alpha: VectorAlpha;
    direct_alpha.amount = 10;
    direct_alpha.flag = 2 as byte;
    mut isolated_beta: VectorBeta;
    mut written_alpha: VectorAlpha;
    mut written_beta: VectorBeta;
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut values: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    unsafe {
        isolated_beta.amount = 5;
        isolated_beta.marker = 3 as byte;
        written_alpha.amount = 0;
        written_alpha.flag = 0 as byte;
        written_beta.amount = 0;
        written_beta.marker = 0 as byte;
        mut status := host_vector_alpha(&direct_alpha, &isolated_beta,
            &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 2);
        guard missing := values.Get(1) else {
            return status + written_alpha.amount + written_beta.amount;
        }
        return missing;
    }
}

func defer_after_status() {
    mut direct_alpha: VectorAlpha;
    direct_alpha.amount = 10;
    direct_alpha.flag = 2 as byte;
    mut isolated_beta: VectorBeta;
    mut written_alpha: VectorAlpha;
    mut written_beta: VectorBeta;
    unsafe {
        isolated_beta.amount = 5;
        isolated_beta.marker = 3 as byte;
        written_alpha.amount = 0;
        written_alpha.flag = 0 as byte;
        written_beta.amount = 0;
        written_beta.marker = 0 as byte;
        defer os.LogStr("vector_defer_marker");
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta,
            &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 0));
        os.LogInt(written_alpha.amount);
        os.LogInt(written_beta.amount);
    }
}

func main() int {
    mut direct_alpha: VectorAlpha;
    direct_alpha.amount = 10;
    direct_alpha.flag = 2 as byte;
    mut isolated_beta: VectorBeta;
    mut written_alpha: VectorAlpha;
    mut written_beta: VectorBeta;
    unsafe {
        isolated_beta.marker = 3 as byte;
        isolated_beta.amount = 5;
        written_alpha.amount = 0;
        written_alpha.flag = 0 as byte;
        written_beta.marker = 0 as byte;
        written_beta.amount = 0;
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 0));
        os.LogInt(written_alpha.amount);
        os.LogInt(written_beta.amount);
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 1));
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 2));
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 3));
        os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 4));
        mut written_beta_second: VectorBeta;
        written_beta_second.marker = 0 as byte;
        written_beta_second.amount = 0;
        mut written_alpha_second: VectorAlpha;
        written_alpha_second.amount = 0;
        written_alpha_second.flag = 0 as byte;
        os.LogInt(host_vector_beta(&isolated_beta, &direct_alpha, &written_beta_second as *VectorBeta, &written_alpha_second as *VectorAlpha, 0));
        os.LogInt(written_beta_second.amount);
        os.LogInt(written_alpha_second.amount);
        os.LogInt(host_vector_beta(&isolated_beta, &direct_alpha, &written_beta_second as *VectorBeta, &written_alpha_second as *VectorAlpha, 1));
        os.LogInt(host_vector_beta(&isolated_beta, &direct_alpha, &written_beta_second as *VectorBeta, &written_alpha_second as *VectorAlpha, 2));
        os.LogInt(host_vector_beta(&isolated_beta, &direct_alpha, &written_beta_second as *VectorBeta, &written_alpha_second as *VectorAlpha, 3));
        os.LogInt(host_vector_beta(&isolated_beta, &direct_alpha, &written_beta_second as *VectorBeta, &written_alpha_second as *VectorAlpha, 4));
        os.LogInt(host_vector_alias_pair(&direct_alpha, &written_alpha));
        os.LogInt(host_vector_scalar_mix(&direct_alpha, &written_alpha, 7 as byte, true));
    }
    os.LogInt(return_after_status());
    os.LogInt(direct_only_status());
    os.LogInt(guard_after_status());
    defer_after_status();
    return 0;
}
