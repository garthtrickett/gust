import "phase20_resource_enforcement_module.gst" as resource;

type Choice enum {
    First,
    Second
}

func pass_through(handle: resource.Handle) resource.Handle {
    return handle;
}

func main() int {
    mut branch_handle := resource.acquire();
    mut close_first := 1;
    if close_first {
        resource.consume(branch_handle);
    } else {
        resource.consume(branch_handle);
    }

    mut match_handle := resource.acquire();
    mut choice: Choice;
    unsafe {
        choice.tag = 0;
    }
    match choice {
        First => {
            resource.consume(match_handle);
        }
        Second => {
            resource.consume(match_handle);
        }
    }

    mut returned_handle := pass_through(resource.acquire());
    mut observed := resource.read(&returned_handle);
    resource.consume(returned_handle);
    return observed;
}
