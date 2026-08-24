import "phase20_protected_access_module.gst" as protected;

func main() int {
    mut first_value: protected.ProtectedValue[ctx];
    mut second_value: protected.ProtectedValue[ctx];
    mut first := protected.acquire(&first_value, 1);
    mut second := protected.acquire(&second_value, 2);
    mut view := protected.ambiguous_access(&first, &second);
    return view.value;
}
