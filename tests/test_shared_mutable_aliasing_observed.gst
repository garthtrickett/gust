// Evidence fixture for VISION.md section 26, not a guard.
//
// References carry no mutability and there is no aliasing analysis. This program
// passes two `&Box[ctx]` arguments that alias the same value and writes through
// both. It compiles and prints 111.
//
// If mutation through references is ever restricted, this program must stop
// compiling and this fixture becomes a compile-fail test. Until then it records
// what the compiler actually permits.

type Box[ctx] struct { n: int }

func bump(b: &Box[ctx]) {
    (*b).n = (*b).n + 1;
}

func bump_twice(x: &Box[ctx], y: &Box[ctx]) {
    (*x).n = (*x).n + 10;
    (*y).n = (*y).n + 100;
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut b: Box[arena];
    b.n = 0;
    bump(&b);
    bump_twice(&b, &b);
    os.LogInt(b.n);
}
