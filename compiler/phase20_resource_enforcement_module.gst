#[linear]
#[destructor(destroy_handle)]
#[opaque]
type Handle struct {
    token: int
}

#[private]
func destroy_handle(resource: Handle) {
    mut observed := resource.token;
}

func acquire() Handle {
    mut resource: Handle;
    resource.token = 42;
    return resource;
}

func read(resource: &Handle) int {
    return resource.token;
}

func same_module_success() int {
    mut resource: Handle;
    resource.token = 5;
    destroy_handle(move resource);
    return 5;
}
