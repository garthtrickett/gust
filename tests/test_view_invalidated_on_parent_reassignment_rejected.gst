func main() {
    mut temp := os.MockPayload();
    mut view := temp;
    temp = os.MockPayload();
    os.LogInt(view[0]);
}