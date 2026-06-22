type MyPod struct {
    x: int,
    y: int
}
func main() {
    mut p1: MyPod;
    p1.x = 10;
    mut p2 := move p1;
}