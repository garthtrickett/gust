#[linear]
#[destructor(phase13_destroy_composition_resource)]
#[opaque]
type Phase13CompositionResourceMetadata struct {
    handle: int
}

#[private]
func phase13_destroy_composition_resource(resource: Phase13CompositionResourceMetadata) {
}

func main() int {
    return 17;
}
