type Shape enum {
    Circle { radius: int },
    Rectangle { width: int, height: int },
    Point
}

func process(shape: Shape) int {
    match shape {
        Circle => {
            return shape.Circle.radius;
        }
        Point => {
            return 0;
        }
    }
}