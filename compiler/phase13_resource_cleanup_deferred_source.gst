#[linear]
type Phase13DeferredResource struct {
    handle: int
}

func phase13_close_resource(resource: &Phase13DeferredResource) {
}

func main() int {
    mut resource: Phase13DeferredResource;
    resource.handle = 7;
    defer phase13_close_resource(&resource);
    return resource.handle;
}