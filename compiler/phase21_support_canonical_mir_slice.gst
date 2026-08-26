// Patch 21.12 support-library qualification root.
//
// This source imports the non-selected support modules from the live
// canonical_mir_authorities compiler slice.  Patch 21.13 owns mir.gst itself.
import "mir_layout.gst" as mir_layout_support;
import "mir_resource_authority.gst" as mir_resource_authority_support;
import "mir_function_abi_authority.gst" as mir_function_abi_support;
import "mir_function_call.gst" as mir_function_call_support;
import "mir_integer_conversion.gst" as mir_integer_conversion_support;
import "mir_pointer.gst" as mir_pointer_support;
import "mir_stack_slot.gst" as mir_stack_slot_support;
import "mir_memory_access.gst" as mir_memory_access_support;
import "mir_string_view.gst" as mir_string_view_support;
import "mir_array_slice.gst" as mir_array_slice_support;
import "mir_struct_layout.gst" as mir_struct_layout_support;
import "mir_enum.gst" as mir_enum_support;
import "mir_aggregate_transport.gst" as mir_aggregate_transport_support;
import "mir_resource_value.gst" as mir_resource_value_support;

func main() int {
    return 0;
}
