import "phase21_resource_sync_renamed_module.gst" as asset;

type BranchChoice enum {
    Left,
    Right
}

func inner_outer() {
    mut exterior := asset.obtain(11);
    if 1 {
        mut interior := asset.obtain(12);
    }
}

func boxed_pair() {
    mut pair: asset.PairBox;
    pair.left = asset.obtain(13);
    pair.right = asset.obtain(14);
}

func return_path() int {
    mut pending := asset.obtain(15);
    return 19;
}

func scheduled_path() {
    mut scheduled := asset.obtain(16);
    defer asset.finish(scheduled);
}

func loop_path() {
    mut iterations := 0;
    while iterations < 1 {
        mut current := asset.obtain(17);
        iterations = iterations + 1;
    }
}

func selected_path() {
    mut choice: BranchChoice;
    unsafe {
        choice.tag = 1;
    }
    match choice {
        Left => {
            mut left := asset.obtain(18);
        }
        Right => {
            mut right := asset.obtain(19);
        }
    }
}

func explicit_path() {
    mut value := asset.obtain(20);
    asset.finish(value);
}

func main() int {
    inner_outer();
    boxed_pair();
    os.LogInt(return_path());
    scheduled_path();
    loop_path();
    selected_path();
    explicit_path();
    return 0;
}
