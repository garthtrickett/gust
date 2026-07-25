// Future positive fixture: imported result controls a branch and rejoins.
import "../phase13_runtime_module_helper_source.gst" as runtime_helper;

func main() int {
    mut result := 0;
    if runtime_helper.add_one(0) > 0 {
        result = runtime_helper.add_one(40);
    } else {
        result = 0;
    }
    return result;
}