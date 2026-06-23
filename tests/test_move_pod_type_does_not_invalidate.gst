type MyPod struct {
    x: int,
    y: int
}
func main() { 
    mut p: MyPod;
    p.x = 10;
    p.y = 20;
    mut p2 := move p;
    os.LogInt(p.x);
    mut val := 42;
    mut moved_val := move val;
    os.LogInt(val);
}
