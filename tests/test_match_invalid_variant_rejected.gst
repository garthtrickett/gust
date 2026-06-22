type Shape enum {
    Circle { radius: int },
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
        Triangle => {
            return 3;
        }
    }
}