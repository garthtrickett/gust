type Node struct {
    val: int
}
func inspect_node(n: &Node) int {
    unsafe {
        // Temporarily using raw deref style or selector
        return n.val;
    }
}
func main() {
    mut n: Node;
    n.val = 42;
    mut res := inspect_node(&n);
    os.LogInt(res);
}
