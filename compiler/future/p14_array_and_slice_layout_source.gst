// Future positive fixture: fixed array and slice layout.
func main() int {
    mut values := [2, 3, 5];
    mut view := values.slice();
    return view[0] + view[2];
}