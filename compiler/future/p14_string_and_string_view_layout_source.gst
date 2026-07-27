// Future positive fixture: string literal and borrowed string view layout.
func main() int {
    mut text := "gust";
    mut view := text.view();
    return view.len();
}