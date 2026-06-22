type StatusPacket struct {
    ID: int,
    Active: byte,
    Verified: byte
}

func main() {
    mut payload := os.MockPayload();
    mut result := payload as &StatusPacket;

    if result.Ok {
        result.Val.ID = 101;
        result.Val.Active = 1;
        result.Val.Verified = 0;

        // Case A: Valid flags
        mut ok1 := StatusPacket_IsValid(&result.Val);
        os.LogInt(ok1);

        // Case B: Corrupted flag
        result.Val.Active = 5;
        mut ok2 := StatusPacket_IsValid(&result.Val);
        os.LogInt(ok2);
    } else {
        os.LogInt(999);
    }
}
