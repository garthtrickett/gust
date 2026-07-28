// Phase 14.4 stable typed-pointer and nullability diagnostics.

import "mir_pointer.gst" as pointer;

func mir_pointer_diagnostic(pointer_type: pointer.MirPointerType[ctx], operation_kind: str, reason_code: str, ctx: &Arena) str {
    mut output := "gust_pointer_diagnostic: taxonomy=gust.pointer.diagnostic.v1";
    output = std.Concat(output, " pointer_type=");
    output = std.Concat(output, pointer_type.pointer_type_id);
    output = std.Concat(output, " pointee_type=");
    output = std.Concat(output, pointer_type.pointee_type_id);
    output = std.Concat(output, " pointee_layout=");
    output = std.Concat(output, pointer_type.pointee_layout_id);
    output = std.Concat(output, " target=");
    output = std.Concat(output, pointer_type.target_triple);
    output = std.Concat(output, " pointer_width=");
    output = std.Concat(output, std.FormatInt(pointer_type.pointer_size * 8));
    output = std.Concat(output, " mutability=");
    output = std.Concat(output, pointer_type.mutability);
    output = std.Concat(output, " nullability=");
    output = std.Concat(output, pointer_type.nullability);
    output = std.Concat(output, " address_space=");
    output = std.Concat(output, pointer_type.address_space);
    output = std.Concat(output, " operation=");
    output = std.Concat(output, operation_kind);
    output = std.Concat(output, " reason_code=");
    output = std.Concat(output, reason_code);
    return std.Clone(ctx, output);
}