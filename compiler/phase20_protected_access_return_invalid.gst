import "phase20_protected_access_module.gst" as protected;

func leak(value: &protected.ProtectedValue[ctx]) &protected.ProtectedValue[ctx] {
    mut owner := protected.acquire(value, 1);
    mut view := protected.access(&owner);
    return view;
}

func main() int {
    return 0;
}
