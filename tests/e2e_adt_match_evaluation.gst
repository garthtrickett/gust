type Shape enum {
    Circle { radius: int },
    Rectangle { width: int, height: int },
    Point
}

func process(shape: Shape) int {
    match shape {
        Circle => {
            unsafe {
                return shape.Circle.radius;
            }
        }
        Rectangle => {
            unsafe {
                return shape.Rectangle.width + shape.Rectangle.height;
            }
        }
        Point => {
            return 123;
        }
    }
}

func main() {
    mut s1: Shape;
    mut s2: Shape;
    mut s3: Shape;
    unsafe {
        s1.tag = 0;
        s1.Circle.radius = 42;

        s2.tag = 1;
        s2.Rectangle.width = 10;
        s2.Rectangle.height = 20;

        s3.tag = 2;
    }

    os.LogInt(process(s1));
    os.LogInt(process(s2));
    os.LogInt(process(s3));
}
