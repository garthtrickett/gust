import "phase22_default_index_initialization_helper.gst" as helper;

type Phase22DefaultIndexHolder[ctx] struct {
    index: Index[int, ctx]
}

func index_is_empty(value: Index[int, ctx]) int {
    if value == empty[Index[int, ctx]] {
        return 1;
    }
    return 0;
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut scalar: Index[int, ctx];
    if scalar != empty[Index[int, ctx]] {
        return 41;
    }

    mut holder: Phase22DefaultIndexHolder[ctx];
    if holder.index != empty[Index[int, ctx]] {
        return 42;
    }

    return helper.expected_exit();
}
