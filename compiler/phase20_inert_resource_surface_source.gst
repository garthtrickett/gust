import "phase20_inert_resource_surface_module.gst" as resource;

// Patch 20.6 control: all three attributes are metadata-only. External direct
// construction, representation access, and private function calls still use
// the exact pre-attribute permissions until Patch 20.8.
func main() int {
    mut handle: resource.Guard;
    handle.token = 42;
    resource.close_guard(handle);
    return handle.token;
}
