type Shape enum { Circle { radius: int } }
func accept_val(x: int) {
    os.LogInt(x);
}
func main() {
    mut s: Shape;
    s.tag = 0;
    s.Circle.radius = 42;
    match s {
        Circle { radius } => {
            accept_val(*radius);
        }
    }
}