func pass(value: str) str {
    return value;
}

func main() {
    mut payload := os.MockPayload();
    os.LogInt(len(payload));
    os.LogStr(pass("slice"));
}
