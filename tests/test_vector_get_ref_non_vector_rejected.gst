func main() {
    mut not_vec := 123;

    // Reject: GetRef is only defined for std.Vector receivers.
    mut bad_ref := not_vec.GetRef(0);
    unsafe {
        os.LogInt(*bad_ref);
    }
}
