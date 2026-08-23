#[linear]
#[destructor(destroy_handle)]
#[opaque]
type Handle struct {
    token: int
}

type HandleBox struct {
    handle: Handle
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

func consume(resource: Handle) {
    destroy_handle(resource);
}

func assignment_success() int {
    mut destination: Handle;
    destination = acquire();
    mut observed := read(&destination);
    destroy_handle(destination);
    return observed;
}

func alias_success() int {
    mut original := acquire();
    mut alias := original;
    mut observed := read(&alias);
    destroy_handle(alias);
    return observed;
}

func aggregate_success() int {
    mut box: HandleBox;
    box.handle = acquire();
    mut observed := read(&box.handle);
    destroy_handle(box.handle);
    return observed;
}

func return_acquired() Handle {
    return acquire();
}

func returned_success() int {
    mut returned := return_acquired();
    mut observed := read(&returned);
    destroy_handle(returned);
    return observed;
}

func transfer_success() int {
    return assignment_success() + alias_success() + aggregate_success() + returned_success();
}

func same_module_success() int {
    mut resource: Handle;
    resource.token = 5;
    destroy_handle(move resource);
    return 5;
}
