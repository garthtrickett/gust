type ListNode[ctx] struct {
    val: int,
    next: Index[ListNode, ctx]
}

func process_list(ctx: &Arena, head: Index[ListNode, ctx]) int {
    mut curr := head;
    mut sum := 0;
    while curr != null {
        sum = sum + ctx[curr].val;
        curr = ctx[curr].next;
    }
    return sum;
}

func main() {
    mut c := os.Arena.New();
    defer c.Free();

    mut n1: Index[ListNode, c] := os.ArenaAlloc(c);
    c[n1].val = 10;

    mut n2: Index[ListNode, c] := os.ArenaAlloc(c);
    c[n2].val = 20;

    c[n1].next = n2;
    c[n2].next = null;

    mut total := process_list(c, n1);
    os.LogInt(total);
}