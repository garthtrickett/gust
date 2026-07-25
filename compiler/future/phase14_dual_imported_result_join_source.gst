// Future positive fixture: two imported results join in deterministic order.
import "../phase11_module_import_math_source.gst" as math;
import "../phase13_runtime_module_helper_source.gst" as runtime_helper;

func main() int {
    mut left := math.lift(20, true);
    mut right := runtime_helper.add_one(20);
    return left + right;
}