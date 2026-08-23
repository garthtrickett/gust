import "phase20_inert_resource_surface_module.gst" as resource;

// Patch 20.6 historical control, reclassified by Patch 20.8: the same external
// construction, representation access, and private call must now all reject.
func main() int {
    mut handle: resource.Guard;
    handle.token = 42;
    resource.close_guard(handle);
    return 0;
}
