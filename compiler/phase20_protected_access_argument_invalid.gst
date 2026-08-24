import "phase20_protected_access_module.gst" as protected;

func main() int {
    mut value: protected.ProtectedValue[ctx];
    value.value = 1;
    mut owner := protected.acquire(&value, 1);
    mut view := protected.access(&owner);
    mut observed := protected.sink(view);
    protected.consume(owner);
    return observed;
}
