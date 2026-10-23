// Independent input/output arenas; retained public success expectation.
import "../src/stdlib/native_bytes.gst" as native;

// Public safe consumer: only the completed ticket is read, in its output arena.
func main() int {
    mut destination := os.Arena.New();
    defer destination.Free();
    mut input_arena := os.Arena.New();
    defer input_arena.Free();
    mut input: std.Vector[byte, input_arena] := std.VectorNew(&input_arena);
    input.Push(3 as byte);
    input.Push(4 as byte);
    mut result := native.compress(&destination, &input, 64, 6);
    match result {
        Bytes { ticket } => {
            mut copied := *ticket;
            mut bytes := destination.get_ref(copied);
            return 100 + len(bytes);
        }
        Error { code } => { return *code; }
    }
}
