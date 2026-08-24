#[linear]
#[destructor(destroy_phase20_generic_guard_resource)]
#[opaque]
type Phase20GenericGuardResource[ctx] struct {
    token: int
}

#[private]
func destroy_phase20_generic_guard_resource(resource: Phase20GenericGuardResource[ctx]) {
}

type Phase20GuardValue[ctx] struct {
    value: int
}

type Phase20ReferenceCapture[ctx] struct {
    value: &Phase20GuardValue[ctx]
}

func capture_phase20_reference(value: &Phase20GuardValue[ctx]) Phase20ReferenceCapture[ctx] {
    mut result: Phase20ReferenceCapture[ctx];
    result.value = value;
    return result;
}

func main() int {
    return 37;
}
