type MyResult[T, E, ctx] enum {
    Ok { val: T },
    Err { error: E }
}

type MyOption[T, ctx] enum {
    Some { val: T },
    None
}

func create_vector(ctx: &Arena) std.Vector[MyOption[MyResult[int, str, ctx], ctx], ctx] {
    mut vec: std.Vector[MyOption[MyResult[int, str, ctx], ctx], ctx] := std.VectorNew(ctx);

    mut r1: MyResult[int, str, ctx];
    mut o1: MyOption[MyResult[int, str, ctx], ctx];
    mut r2: MyResult[int, str, ctx];
    mut o2: MyOption[MyResult[int, str, ctx], ctx];
    mut o3: MyOption[MyResult[int, str, ctx], ctx];

    unsafe {
        r1.tag = 0; // Ok
        r1.Ok.val = 42;

        o1.tag = 0; // Some
        o1.Some.val = r1;
    }

    vec.Push(o1);

    unsafe {
        r2.tag = 1; // Err
        r2.Err.error = "something went wrong";

        o2.tag = 0; // Some
        o2.Some.val = r2;
    }

    vec.Push(o2);

    unsafe {
        o3.tag = 1; // None
    }

    vec.Push(o3);

    return vec;
}

func process_vector(vec: std.Vector[MyOption[MyResult[int, str, ctx], ctx], ctx]) { 
    mut i := 0;
    while i < len(vec) {
        mut opt := vec[i];
        match opt {
            Some => {
                unsafe {
                    mut res := opt.Some.val;
                    match res {
                        Ok => {
                            os.LogInt(res.Ok.val);
                        }
                        Err => {
                            os.LogStr(res.Err.error);
                        }
                    }
                }
            }
            None => {
                os.LogStr("None");
            }
        }
        i = i + 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut vec := create_vector(ctx);
    process_vector(vec);
}
