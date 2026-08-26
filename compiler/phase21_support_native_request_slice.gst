// Patch 21.12 support-library qualification root.
//
// This source imports the non-entry support modules from the live
// native_request_route_and_entry slice.  The compiler entry remains owned by
// the later full-compiler qualification patches.
import "mir_primitive_layout.gst" as native_primitive_layout_support;
import "mir_native_backend_request.gst" as native_request_support;
import "mir_native_backend_source_route.gst" as native_source_route_support;

func main() int {
    return 0;
}
