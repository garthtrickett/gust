import "phase24_resource_implicit_transfer_alias_module.gst" as unrelated;

func main() int {
    mut owner := unrelated.make_permit(73);
    mut copy := owner;
    mut forbidden := unrelated.inspect_permit(&owner);
    return forbidden - unrelated.inspect_permit(&copy);
}
