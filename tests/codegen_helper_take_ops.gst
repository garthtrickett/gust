type MyPod struct {
    x: int,
    y: int
}
type MyLinear struct {
    ptr: *int
}
func main() {
    mut p1: MyPod;
    p1.x = 10;
    mut p2 := take p1;

    mut l1: MyLinear;
    mut l2 := take l1;
}