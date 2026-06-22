type Packet struct {
    ProtocolID: int,
    Length: int
}

func main() {
    mut payload := os.MockPayload();
    
    guard p := payload as &Packet else {
        os.LogInt(0);
        return;
    }

    os.LogInt(p.ProtocolID);
}