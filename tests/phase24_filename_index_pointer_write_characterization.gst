func main() {
    mut value := 1;
    mut pointer := &value;
    mut pointer_view := &pointer;
    *pointer = 2;
    os.LogInt(*(*pointer_view));
}
