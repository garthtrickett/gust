// Future positive fixture: imported call result carried through one CFG join.
import "../phase11_module_import_math_source.gst" as math;

func main() int {
    mut result := 0;
    if true {
        result = math.lift(39, true);
    } else {
        result = 0;
    }
    return result;
}