import "phase20_whole_program_scalar_helper.gst" as scalar;
import "phase20_cross_feature_resource_module.gst" as resource;

extern func phase20_cross_feature_resource_event(token: int) int;
extern func phase20_cross_feature_probe() int;

type Phase20CrossFeatureNode[ctx] struct {
    value: int
}

func exercise_brand_and_liveness(origin: &Arena, destination: &Arena) int {
    mut source: Index[Phase20CrossFeatureNode, origin] := os.ArenaAlloc(origin);
    mut source_ref := origin.get_ref(source);
    source_ref.value = 40;
    mut cloned: Index[Phase20CrossFeatureNode, destination] := std.Clone(destination, source);
    mut cloned_ref := destination.get_ref(cloned);
    cloned_ref.value = cloned_ref.value + 2;
    return cloned_ref.value;
}

func exercise_resource_cleanup() {
    mut outer := resource.acquire_cross_feature_resource(1);
    if 1 {
        mut inner := resource.acquire_cross_feature_resource(2);
    }
}

func main() int {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();

    mut value := scalar.raise(37);
    mut step := 0;
    while step < 8 {
        value = value + 1;
        step = step + 1;
    }
    if exercise_brand_and_liveness(&origin, &destination) != 42 {
        return 81;
    }
    unsafe {
        phase20_cross_feature_resource_event(value);
    }
    exercise_resource_cleanup();
    unsafe {
        return phase20_cross_feature_probe();
    }
}
