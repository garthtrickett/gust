import "mir.gst" as mir;
import "mir_layout.gst" as layout;

// Phase 10 generic native-backend request protocol.
//
// This compiler-owned model serializes one validated canonical whole-program
// MIR bundle reference plus one opaque final-executable intent. It performs no
// filesystem access, process spawning, object emission, linking, publication,
// fallback, or implementation-specific routing.
type MirNativeBackendRequest[ctx] struct {
    target_triple: str,
    object_format: str,
    output_path: str,
    program_mir_bundle_path: str,
    program_bundle: mir.MirProgramBundle[ctx],
    layout_table: layout.MirLayoutTable[ctx]
}

func mir_native_backend_request_path_is_safe(path: str) int {
    if len(path) == 0 {
        return 0;
    }
    if std.str_find(path, "\n") != 0 - 1 {
        return 0;
    }
    if std.str_find(path, "\r") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_native_backend_request_path_is_absolute(path: str) int {
    if mir_native_backend_request_path_is_safe(path) == 0 {
        return 0;
    }

    if std.str_byte_at(path, 0) == 47 {
        return 1;
    }

    if len(path) >= 3 {
        if std.str_byte_at(path, 1) == 58 {
            mut separator := std.str_byte_at(path, 2);
            if separator == 47 || separator == 92 {
                return 1;
            }
        }
    }

    return 0;
}

func mir_native_backend_make_request_with_layout_table(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut request: MirNativeBackendRequest[ctx];
    request.target_triple = std.Clone(ctx, target_triple);
    request.object_format = std.Clone(ctx, object_format);
    request.output_path = std.Clone(ctx, output_path);
    request.program_mir_bundle_path = std.Clone(ctx, program_mir_bundle_path);
    request.program_bundle = program_bundle;
    request.layout_table = layout_table;
    return request;
}

func mir_native_backend_make_request(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut layout_table := layout.mir_layout_make_unfrozen_table(
        target_triple,
        ctx
    );
    return mir_native_backend_make_request_with_layout_table(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        ctx
    );
}

func mir_native_backend_request_is_valid(request: MirNativeBackendRequest[ctx], ctx: &Arena) int {
    if mir.mir_program_bundle_field_is_safe(request.target_triple, 0) == 0 {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(request.object_format, 0) == 0 {
        return 0;
    }
    if mir_native_backend_request_path_is_absolute(request.output_path) == 0 {
        return 0;
    }
    if mir_native_backend_request_path_is_absolute(request.program_mir_bundle_path) == 0 {
        return 0;
    }
    if std.str_eq(request.output_path, request.program_mir_bundle_path) == 1 {
        return 0;
    }
    if mir.mir_program_bundle_is_valid(request.program_bundle, ctx) == 0 {
        return 0;
    }
    if layout.mir_layout_table_is_valid(request.layout_table, ctx) == 0 {
        return 0;
    }
    if std.str_eq(
        request.layout_table.target.target_triple,
        request.target_triple
    ) == 0 {
        return 0;
    }
    return 1;
}

func mir_native_backend_request_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_native_backend_request(request: MirNativeBackendRequest[ctx], ctx: &Arena) str {
    if mir_native_backend_request_is_valid(request, ctx) == 0 {
        return "format: invalid\n";
    }

    mut output := "format: gust.native_backend.request.v1\n";
    output = mir_native_backend_request_append_field(
        output,
        "driver_protocol",
        "gust.native_backend.driver.v1",
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "artifact_kind",
        "native_executable",
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "target_triple",
        request.target_triple,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "object_format",
        request.object_format,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "output_path",
        request.output_path,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "program_mir_bundle_path",
        request.program_mir_bundle_path,
        ctx
    );
    output = std.Concat(
        output,
        layout.mir_serialize_layout_table_for_request(
            request.layout_table,
            ctx
        )
    );
    return std.Clone(ctx, output);
}
