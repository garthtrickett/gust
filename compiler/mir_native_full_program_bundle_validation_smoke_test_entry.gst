import "mir_native_backend_full_program_source.gst" as fullprog;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func call_node(
    text: str,
    second_text: str,
    result_type: str,
    ctx: &Arena
) fullprog.MirNativeFullProgramNode[ctx] {
    return fullprog.mir_native_full_program_make_node(
        "Call", result_type, text, second_text, 0, 0, 7, 3, 0, 0, ctx
    );
}

func arg_node(type_identity: str, ctx: &Arena) fullprog.MirNativeFullProgramNode[ctx] {
    return fullprog.mir_native_full_program_make_node(
        "Literal", type_identity, "", "", 0, 0, 7, 3, 0, 0, ctx
    );
}

// One call plus its argument, appended to a fresh model.
func model_with_call(
    text: str,
    second_text: str,
    arg_type: str,
    result_type: str,
    ctx: &Arena
) fullprog.MirNativeFullProgramModel[ctx] {
    mut model := fullprog.mir_native_full_program_empty_model(ctx);
    mut callee_index := fullprog.mir_native_full_program_push_node(
        model.nodes, arg_node("Int", ctx), ctx
    );
    mut arg_index := fullprog.mir_native_full_program_push_node(
        model.nodes, arg_node(arg_type, ctx), ctx
    );
    mut call := call_node(text, second_text, result_type, ctx);
    call = fullprog.mir_native_full_program_node_with_child(call, callee_index, ctx);
    call = fullprog.mir_native_full_program_node_with_child(call, arg_index, ctx);
    fullprog.mir_native_full_program_push_node(model.nodes, call, ctx);
    return model;
}

func add_call(
    model: fullprog.MirNativeFullProgramModel[ctx],
    text: str,
    second_text: str,
    arg_type: str,
    result_type: str,
    ctx: &Arena
) fullprog.MirNativeFullProgramModel[ctx] {
    mut updated := model;
    mut callee_index := fullprog.mir_native_full_program_push_node(
        updated.nodes, arg_node("Int", ctx), ctx
    );
    mut arg_index := fullprog.mir_native_full_program_push_node(
        updated.nodes, arg_node(arg_type, ctx), ctx
    );
    mut call := call_node(text, second_text, result_type, ctx);
    call = fullprog.mir_native_full_program_node_with_child(call, callee_index, ctx);
    call = fullprog.mir_native_full_program_node_with_child(call, arg_index, ctx);
    fullprog.mir_native_full_program_push_node(updated.nodes, call, ctx);
    return updated;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // 1. One symbol, one signature: no conflict.
    mut consistent := model_with_call("os_LogInt", "", "Int", "Void", ctx);
    consistent = add_call(consistent, "os_LogInt", "", "Int", "Void", ctx);
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(consistent, ctx)) != 0 {
        fail("CR-19 smoke: identical signatures must not conflict");
    }

    // 2. One symbol, two signatures: conflict, naming the symbol.
    mut conflicting := model_with_call("os_LogInt", "", "Int", "Void", ctx);
    conflicting = add_call(conflicting, "os_LogInt", "", "Str", "Void", ctx);
    mut conflict := fullprog.mir_native_full_program_runtime_signature_conflict(conflicting, ctx);
    if len(conflict) == 0 {
        fail("CR-19 smoke: differing signatures for one symbol must conflict");
    }
    if std.str_find(conflict, "os_LogInt") == 0 - 1 {
        fail("CR-19 smoke: the conflict must name the symbol");
    }

    // 3. ALIAS std_Clone -> std_Clone_str. Two spellings of one symbol with
    //    different signatures must conflict; without the alias they are two
    //    symbols and nothing is detected. No end-to-end fixture reaches this,
    //    because the only corpus instance conflicts on os_LogInt, unaliased.
    mut aliased := model_with_call("std_Clone", "", "Int", "Str", ctx);
    aliased = add_call(aliased, "std_Clone_str", "", "Str", "Str", ctx);
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(aliased, ctx)) == 0 {
        fail("CR-19 smoke: std_Clone must alias onto std_Clone_str");
    }

    // 4. ALIAS os_Exit -> exit.
    mut exit_alias := model_with_call("os_Exit", "", "Int", "Void", ctx);
    exit_alias = add_call(exit_alias, "exit", "", "Str", "Void", ctx);
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(exit_alias, ctx)) == 0 {
        fail("CR-19 smoke: os_Exit must alias onto exit");
    }

    // 5. ALIAS os_ArenaValidate -> os_Arena_Validate.
    mut validate_alias := model_with_call("os_ArenaValidate", "", "Int", "Void", ctx);
    validate_alias = add_call(validate_alias, "os_Arena_Validate", "", "Str", "Void", ctx);
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(validate_alias, ctx)) == 0 {
        fail("CR-19 smoke: os_ArenaValidate must alias onto os_Arena_Validate");
    }

    // 6. A call with no callee identity is detected, and the diagnostic carries
    //    a source position -- unlike the worker's, which interpolates the empty
    //    name and so has no identity either.
    mut unnameable := model_with_call("", "", "Int", "Void", ctx);
    mut message := fullprog.mir_native_full_program_unnameable_call_diagnostic(unnameable, ctx);
    if len(message) == 0 {
        fail("CR-19 smoke: an empty callee identity must be detected");
    }
    if std.str_find(message, "line 7") == 0 - 1 {
        fail("CR-19 smoke: the unnameable diagnostic must name a source position");
    }

    // 7. A `__`-suffixed symbol is equally unnameable.
    mut suffixed := model_with_call("some_module__", "", "Int", "Void", ctx);
    if len(fullprog.mir_native_full_program_unnameable_call_diagnostic(suffixed, ctx)) == 0 {
        fail("CR-19 smoke: a __-suffixed symbol must be detected");
    }

    // 8. The signature check must ignore what the unnameable check owns, or one
    //    program would report two reasons and the inversions could not be told
    //    apart.
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(unnameable, ctx)) != 0 {
        fail("CR-19 smoke: the signature check must skip unnameable symbols");
    }

    // 9. The allocator skips.
    mut scratch := model_with_call("os_ScratchAlloc", "", "Int", "Int", ctx);
    scratch = add_call(scratch, "os_ScratchAlloc", "", "Str", "Int", ctx);
    if len(fullprog.mir_native_full_program_runtime_signature_conflict(scratch, ctx)) != 0 {
        fail("CR-19 smoke: os_ScratchAlloc must be skipped");
    }

    os.LogStr("CR-19 full-program bundle validation smoke passed");
}
