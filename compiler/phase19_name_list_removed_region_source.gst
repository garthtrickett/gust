// Phase 19.8 structural brand-role parity, arbitrary-spelling arm.
type Phase19NameListHolder[region] struct {
    values: std.Vector[int, region]
}

func phase19_name_list_mutable_spelling() int {
    mut region: str := "x";
    region = "y";
    return len(region);
}

func phase19_name_list_value(region: &Arena) int {
    mut values: std.Vector[int, region] := std.VectorNew(region);
    values.Push(19);
    mut holder: Phase19NameListHolder[region];
    holder.values = values;
    return holder.values[0];
}

func main() int {
    mut region := os.Arena.New();
    defer region.Free();
    if phase19_name_list_mutable_spelling() != 1 {
        return 1;
    }
    return phase19_name_list_value(&region);
}
