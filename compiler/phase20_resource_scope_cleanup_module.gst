#[linear]
#[destructor(destroy_handle)]
#[opaque]
type Handle struct {
    token: int
}

type HandleBox struct {
    first: Handle,
    second: Handle
}

#[private]
func destroy_handle(resource: Handle) {
    os.LogInt(resource.token);
}

func acquire(token: int) Handle {
    mut resource: Handle;
    resource.token = token;
    return resource;
}

func consume(resource: Handle) {
    destroy_handle(resource);
}

