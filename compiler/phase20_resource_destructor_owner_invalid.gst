import "phase20_resource_wrong_owner_helper.gst" as helper;

#[linear]
#[destructor(phase20_resource_wrong_owner_helper__destroy)]
#[opaque]
type WrongOwnerCleanup struct {
    token: int
}

func main() int {
    return 0;
}
