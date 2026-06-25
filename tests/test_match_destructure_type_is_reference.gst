type Shape enum { Circle { radius: int } }
func accept_val(x: int) {}
func main() {
    mut s: Shape;
    match s {
        Circle { radius } => {
            accept_val(radius); 
        }
    }
}