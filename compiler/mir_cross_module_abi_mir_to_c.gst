import "mir_cross_module_abi.gst" as cross_module;
func mir_cross_module_abi_mir_to_c_witness(table: cross_module.MirCrossModuleAbiTable[ctx], ctx: &Arena) str { return std.Clone(ctx,cross_module.mir_serialize_cross_module_abi_for_request(table,ctx)); }
