// Patch 21.12 support-library qualification root.
//
// This source imports the complete native_source_lowering support slice.  It
// records qualification evidence only; it does not select a module-specific
// lowering path.
import "mir_native_backend_capability.gst" as native_capability_support;
import "mir_native_backend_driver.gst" as native_driver_support;
import "mir_native_backend_block_parameter_loop_source.gst" as native_block_loop_support;
import "mir_native_backend_metadata_source.gst" as native_metadata_support;
import "mir_native_backend_direct_call_source.gst" as native_direct_call_support;
import "mir_native_backend_local_state_source.gst" as native_local_state_support;
import "mir_native_backend_module_import_source.gst" as native_module_import_support;
import "mir_native_backend_parameter_argument_source.gst" as native_parameter_argument_support;
import "mir_native_backend_structured_cfg_source.gst" as native_structured_cfg_support;
import "mir_native_backend_scalar_expression_source.gst" as native_scalar_expression_support;
import "mir_native_backend_collection_string_source.gst" as native_collection_string_support;
import "mir_native_backend_filesystem_allocation_source.gst" as native_filesystem_allocation_support;
import "mir_native_backend_resource_sync_source.gst" as native_resource_sync_support;
import "mir_native_backend_generic_source.gst" as native_generic_support;

func main() int {
    return 0;
}
