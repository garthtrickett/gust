type Packet struct {
    ProtocolID: int,
    SeqNum: int,
    Length: int
}

func main() {
    mut payload := os.MockPayload();
    
    // Cast the raw byte slice dynamically to a struct reference
    mut result := payload as &Packet;
    
    if result.Ok {
        os.LogInt(result.Val.ProtocolID);
    } else {
        os.LogInt(0);
    }
}