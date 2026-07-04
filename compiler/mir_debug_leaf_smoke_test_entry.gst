import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func expect_str_eq(actual: str, expected: str, label: str) {
    if std.str_eq(actual, expected) == 0 {
        os.LogStr(label);
        os.LogStr("expected:");
        os.LogStr(expected);
        os.LogStr("actual:");
        os.LogStr(actual);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span := mir.mir_make_empty_span();

    mut int_value: mir.MirValue[ctx] := mir.mir_make_value_int_literal(7, "int", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(int_value), "MirValue.IntLiteral", "MIR leaf debug: int literal kind drifted");

    mut bool_value: mir.MirValue[ctx] := mir.mir_make_value_bool_literal(1, "bool", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(bool_value), "MirValue.BoolLiteral", "MIR leaf debug: bool literal kind drifted");

    mut string_value: mir.MirValue[ctx] := mir.mir_make_value_string_literal("hello", "str", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(string_value), "MirValue.StringLiteral", "MIR leaf debug: string literal kind drifted");

    mut local_read: mir.MirValue[ctx] := mir.mir_make_value_local_read(0, "int", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(local_read), "MirValue.LocalRead", "MIR leaf debug: local read kind drifted");

    mut args := mir.mir_empty_value_vector(ctx);
    mut call_value: mir.MirValue[ctx] := mir.mir_make_value_call("callee", args, "int", span);
    expect_str_eq(mir.mir_debug_value_kind(call_value), "MirValue.Call", "MIR leaf debug: call kind drifted");

    mut local_read_idx := mir.mir_alloc_value(local_read, ctx);

    mut nop_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_nop(span, ctx);
    expect_str_eq(mir.mir_debug_stmt_kind(nop_stmt), "MirStmt.Nop", "MIR leaf debug: nop statement kind drifted");

    mut local_set_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_local_set(0, local_read_idx, span);
    expect_str_eq(mir.mir_debug_stmt_kind(local_set_stmt), "MirStmt.LocalSet", "MIR leaf debug: local-set statement kind drifted");

    mut expr_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_expr(local_read_idx, span);
    expect_str_eq(mir.mir_debug_stmt_kind(expr_stmt), "MirStmt.Expr", "MIR leaf debug: expr statement kind drifted");

    mut return_void: mir.MirTerminator[ctx] := mir.mir_make_terminator_return_void(span, ctx);
    expect_str_eq(mir.mir_debug_terminator_kind(return_void), "MirTerminator.ReturnVoid", "MIR leaf debug: return-void terminator kind drifted");

    mut return_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_return(local_read_idx, span);
    expect_str_eq(mir.mir_debug_terminator_kind(return_term), "MirTerminator.Return", "MIR leaf debug: return terminator kind drifted");

    mut jump_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_jump(1, span, ctx);
    expect_str_eq(mir.mir_debug_terminator_kind(jump_term), "MirTerminator.Jump", "MIR leaf debug: jump terminator kind drifted");

    mut branch_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_branch(local_read_idx, 1, 2, span);
    expect_str_eq(mir.mir_debug_terminator_kind(branch_term), "MirTerminator.Branch", "MIR leaf debug: branch terminator kind drifted");

    mut non_resource: mir.MirResourceKind;
    mut linear_resource: mir.MirResourceKind;
    mut directory_resource: mir.MirResourceKind;
    mut native_handle_resource: mir.MirResourceKind;
    unsafe {
        non_resource.tag = 0;
        linear_resource.tag = 1;
        directory_resource.tag = 2;
        native_handle_resource.tag = 3;
    }
    expect_str_eq(mir.mir_debug_resource_kind(non_resource), "MirResourceKind.NonResource", "MIR metadata debug: non-resource kind drifted");
    expect_str_eq(mir.mir_debug_resource_kind(linear_resource), "MirResourceKind.LinearResource", "MIR metadata debug: linear resource kind drifted");
    expect_str_eq(mir.mir_debug_resource_kind(directory_resource), "MirResourceKind.DirectoryResource", "MIR metadata debug: directory resource kind drifted");
    expect_str_eq(mir.mir_debug_resource_kind(native_handle_resource), "MirResourceKind.NativeHandleResource", "MIR metadata debug: native handle resource kind drifted");

    mut resource_untracked: mir.MirResourceState;
    mut resource_owned: mir.MirResourceState;
    mut resource_borrowed: mir.MirResourceState;
    mut resource_moved: mir.MirResourceState;
    mut resource_closed: mir.MirResourceState;
    mut resource_destructor_scheduled: mir.MirResourceState;
    unsafe {
        resource_untracked.tag = 0;
        resource_owned.tag = 1;
        resource_borrowed.tag = 2;
        resource_moved.tag = 3;
        resource_closed.tag = 4;
        resource_destructor_scheduled.tag = 5;
    }
    expect_str_eq(mir.mir_debug_resource_state(resource_untracked), "MirResourceState.Untracked", "MIR metadata debug: untracked resource state drifted");
    expect_str_eq(mir.mir_debug_resource_state(resource_owned), "MirResourceState.Owned", "MIR metadata debug: owned resource state drifted");
    expect_str_eq(mir.mir_debug_resource_state(resource_borrowed), "MirResourceState.Borrowed", "MIR metadata debug: borrowed resource state drifted");
    expect_str_eq(mir.mir_debug_resource_state(resource_moved), "MirResourceState.Moved", "MIR metadata debug: moved resource state drifted");
    expect_str_eq(mir.mir_debug_resource_state(resource_closed), "MirResourceState.Closed", "MIR metadata debug: closed resource state drifted");
    expect_str_eq(mir.mir_debug_resource_state(resource_destructor_scheduled), "MirResourceState.DestructorScheduled", "MIR metadata debug: destructor-scheduled resource state drifted");

    mut provenance_unknown: mir.MirProvenanceKind;
    mut provenance_local_binding: mir.MirProvenanceKind;
    mut provenance_parameter: mir.MirProvenanceKind;
    mut provenance_return_value: mir.MirProvenanceKind;
    mut provenance_native_boundary: mir.MirProvenanceKind;
    mut provenance_resource_destructor: mir.MirProvenanceKind;
    unsafe {
        provenance_unknown.tag = 0;
        provenance_local_binding.tag = 1;
        provenance_parameter.tag = 2;
        provenance_return_value.tag = 3;
        provenance_native_boundary.tag = 4;
        provenance_resource_destructor.tag = 5;
    }
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_unknown), "MirProvenanceKind.Unknown", "MIR metadata debug: unknown provenance kind drifted");
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_local_binding), "MirProvenanceKind.LocalBinding", "MIR metadata debug: local-binding provenance kind drifted");
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_parameter), "MirProvenanceKind.Parameter", "MIR metadata debug: parameter provenance kind drifted");
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_return_value), "MirProvenanceKind.ReturnValue", "MIR metadata debug: return-value provenance kind drifted");
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_native_boundary), "MirProvenanceKind.NativeBoundary", "MIR metadata debug: native-boundary provenance kind drifted");
    expect_str_eq(mir.mir_debug_provenance_kind(provenance_resource_destructor), "MirProvenanceKind.ResourceDestructor", "MIR metadata debug: resource-destructor provenance kind drifted");

    mut native_not_boundary: mir.MirNativeBoundaryKind;
    mut native_runtime_call: mir.MirNativeBoundaryKind;
    mut native_extern_function: mir.MirNativeBoundaryKind;
    mut native_unsafe_call: mir.MirNativeBoundaryKind;
    mut native_layout_sensitive_call: mir.MirNativeBoundaryKind;
    unsafe {
        native_not_boundary.tag = 0;
        native_runtime_call.tag = 1;
        native_extern_function.tag = 2;
        native_unsafe_call.tag = 3;
        native_layout_sensitive_call.tag = 4;
    }
    expect_str_eq(mir.mir_debug_native_boundary_kind(native_not_boundary), "MirNativeBoundaryKind.NotNativeBoundary", "MIR metadata debug: not-native-boundary kind drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(native_runtime_call), "MirNativeBoundaryKind.RuntimeCall", "MIR metadata debug: runtime-call native boundary kind drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(native_extern_function), "MirNativeBoundaryKind.ExternFunction", "MIR metadata debug: extern-function native boundary kind drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(native_unsafe_call), "MirNativeBoundaryKind.UnsafeNativeCall", "MIR metadata debug: unsafe-native-call boundary kind drifted");
    expect_str_eq(mir.mir_debug_native_boundary_kind(native_layout_sensitive_call), "MirNativeBoundaryKind.LayoutSensitiveCall", "MIR metadata debug: layout-sensitive native boundary kind drifted");

    os.LogStr("SUCCESS: mir debug leaf smoke");
}
