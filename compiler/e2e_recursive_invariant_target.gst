type StatusPacket struct {
    ID: int,
    Active: byte
}
type NestedPacket struct {
    status: StatusPacket,
    val: int
}
func main() {
    mut p: NestedPacket;
    p.status.ID = 100;
    p.status.Active = 1;
    p.val = 50;

    mut is_valid_1 := NestedPacket_IsValid(&p);
    os.LogInt(is_valid_1); // Expected: 1 (Valid)

    unsafe {
        mut val_ptr := &p.status.Active;
        *val_ptr = 5; // Inject invalid byte!
    }

    mut is_valid_2 := NestedPacket_IsValid(&p);
    os.LogInt(is_valid_2); // Expected: 0 (Invalid)
}