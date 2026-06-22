type MyPod struct {
    x: int,
    y: int
}
func main() {
    mut p: MyPod;
    p.x = 10;
    mut taken := take p;
}