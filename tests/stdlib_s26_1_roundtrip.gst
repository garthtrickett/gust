import "../src/stdlib/native_bytes.gst" as native;

// Intended safe public composition; pending closed-caller proof qualification.
func main() int {
    mut destination := os.Arena.New();
    defer destination.Free();
    mut input: std.Vector[byte, destination] := std.VectorNew(&destination);
    input.Push(3 as byte);
    input.Push(4 as byte);
    mut compressed := native.compress(&destination, &input, 64, 6);
    match compressed {
        Bytes { ticket } => {
            mut encoded_ticket := *ticket;
            mut encoded := destination.get_ref(encoded_ticket);
            mut decoded := native.decompress(&destination, encoded, 2);
            match decoded {
                Bytes { ticket } => {
                    mut output_ticket := *ticket;
                    mut output := destination.get_ref(output_ticket);
                    return 100 + (len(output) == 2) * (output[0] == (3 as byte)) * (output[1] == (4 as byte));
                }
                Error { code } => { return *code; }
            }
        }
        Error { code } => { return *code; }
    }
}
