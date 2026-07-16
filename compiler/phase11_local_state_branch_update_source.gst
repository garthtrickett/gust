func main() int {
    mut condition := 1;
    mut selected := 5;
    mut independent := 7;
    if condition > 0 {
        selected = selected + 31;
        independent = selected + 7;
    } else {
        selected = selected + 2;
        independent = selected + 3;
    }
    return independent;
}