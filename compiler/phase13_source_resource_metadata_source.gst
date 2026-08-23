#[linear]
#[destructor(phase13_destroy_source_resource)]
#[opaque]
type Phase13SourceResourceMetadata struct {
    handle: int
}

#[private]
func phase13_destroy_source_resource(resource: Phase13SourceResourceMetadata) {
}

func main() int {
    return 31;
}
