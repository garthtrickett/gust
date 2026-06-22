func main() {
    mut payload := os.MockPayload();
    os.LogInt(payload[0]);
    os.LogInt(len(payload));
}
