type Shape enum { Circle { radius: int } }
func accept_val(x: int) {
    os.LogInt(x);
}
func main() {
    mut s: Shape;
    unsafe {
        s.tag = 0;
        s.Circle.radius = 42;
    }
    match s {
        Circle { radius } => {
            // Step 2: Explicit dereference gets the underlying plain 'int'
            accept_val(*radius);
        }
    }
}
