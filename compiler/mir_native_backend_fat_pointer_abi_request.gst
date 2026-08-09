import "mir_native_backend_abi_request.gst" as base;
import "mir_fat_pointer_abi.gst" as fat;
type MirNativeBackendFatPointerAbiRequest[ctx] struct { format: str, base_request: base.MirNativeBackendAbiRequest[ctx], fat_pointer_table: fat.MirFatPointerAbiTable[ctx] }
func mir_native_backend_fat_pointer_abi_request_is_valid(request: MirNativeBackendFatPointerAbiRequest[ctx], ctx: &Arena) fat.MirFatPointerAbiValidation[ctx] {
    if std.str_eq(request.format, "gust.native_backend.fat_pointer_abi_request.v1") == 0 { return fat.mir_fat_pointer_validation(0, "fat_pointer_request_unknown_format", ctx); }
    mut validation := base.mir_native_backend_abi_request_is_valid(request.base_request, ctx); if validation.valid == 0 { return fat.mir_fat_pointer_validation(0, validation.reason_code, ctx); }
    return fat.mir_fat_pointer_abi_table_validate(request.fat_pointer_table, request.base_request.base_request.base_request.layout_table, request.base_request.abi_authority_table, ctx);
}
