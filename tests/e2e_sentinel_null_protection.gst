type Node[ctx] struct {
    val: int,
    next: Index[Node, ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    // Allocate a node to occupy offset 0 of the Arena
    mut first: Index[Node, ctx] := os.ArenaAlloc(ctx);
    mut first_ref_sentinel := ctx.get_ref(first);
    first_ref_sentinel.val = 999;

    // Create an uninitialized Node structure.
    // Its 'next' field should be initialized to the safe sentinel null (0xFFFFFFFF),
    // NOT the raw 0 (which would incorrectly reference the 'first' node!).
    mut empty_node: Node[ctx];

    // Perform sentinel null check: assert empty_node.next is equal to null (0xFFFFFFFF)
    if empty_node.next == null {
        os.LogInt(1); // 1 = True (Safe)
    } else {
        os.LogInt(0); // 0 = False (Unsafe, collided with first node)
    }
}
