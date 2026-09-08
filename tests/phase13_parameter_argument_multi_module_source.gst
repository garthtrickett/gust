import "phase13_parameter_argument_multi_module_helper_source.gst" as helper;

type Phase13MultiModulePair struct {
    left: int,
    right: int
}

extern func phase13_multi_module_pair_sum(pair: Phase13MultiModulePair) int;

func main() int {
    return helper.lift(41);
}
