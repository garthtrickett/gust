#[linear]
#[destructor(phase13_destroy_deferred_resource)]
#[opaque]
type Phase13DeferredResource struct {
    handle: int
}

#[private]
func phase13_destroy_deferred_resource(resource: Phase13DeferredResource) {
}

func phase13_close_resource(resource: &Phase13DeferredResource) {
}

func main() int {
    mut resource: Phase13DeferredResource;
    resource.handle = 7;
    defer phase13_close_resource(&resource);
    return resource.handle;
}
