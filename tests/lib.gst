import "core.gst" as core;
type Container[T, ctx] struct {
    val: T,
    node: Index[core.CoreNode, ctx]
}
func make_container(ctx: &Arena, val: int) Container[int, ctx] {
    mut c: Container[int, ctx];
    c.val = val;
    c.node = core.make_core_node(ctx);
    return c;
}