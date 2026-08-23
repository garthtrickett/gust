// Future positive fixture: linear resource move, cleanup edge, and destructor scheduling.
#[linear]
#[destructor(destroy_phase14_resource)]
#[opaque]
type Phase14Resource struct {
    handle: int
}

#[private]
func destroy_phase14_resource(resource: Phase14Resource) {
}

func close_resource(resource: &Phase14Resource) {
}

func main() int {
    mut resource: Phase14Resource;
    resource.handle = 9;
    defer close_resource(&resource);
    return resource.handle;
}
