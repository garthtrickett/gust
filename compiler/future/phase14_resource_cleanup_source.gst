// Future positive fixture: linear resource move, cleanup edge, and destructor scheduling.
#[linear]
type Phase14Resource struct {
    handle: int
}

func close_resource(resource: &Phase14Resource) {
}

func main() int {
    mut resource: Phase14Resource;
    resource.handle = 9;
    defer close_resource(&resource);
    return resource.handle;
}