import "phase11_module_import_math_source.gst" as math;
import "phase13_runtime_module_helper_source.gst" as runtime_helper;

func main() int {
    return math.lift(runtime_helper.add_one(39), true);
}