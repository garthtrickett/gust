#[linear]
#[destructor(destroy_phase20_generic_wrong_brand)]
#[opaque]
type Phase20GenericWrongBrand[ctx] struct {
    token: int
}

#[private]
func destroy_phase20_generic_wrong_brand(resource: Phase20GenericWrongBrand[other]) {
}

func main() int {
    return 0;
}
