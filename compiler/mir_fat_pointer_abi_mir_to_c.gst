import "mir_fat_pointer_abi.gst" as fat;
import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
func mir_fat_pointer_abi_mir_to_c_witness(table: fat.MirFatPointerAbiTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str { return std.Clone(ctx, fat.mir_serialize_fat_pointer_abi_for_request(table, layouts, authority, ctx)); }
