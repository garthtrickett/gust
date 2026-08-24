#[linear]
#[destructor(destroy_phase20_generic_wrong_type)]
#[opaque]
type Phase20GenericWrongType[ctx] struct {
    token: int
}

#[private]
func destroy_phase20_generic_wrong_type(resource: int) {
}

func main() int {
    return 0;
}
