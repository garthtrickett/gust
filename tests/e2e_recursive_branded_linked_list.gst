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
    mut n2: Index[ListNode, c] := os.ArenaAlloc(c);

    mut n1_ref_list := c.get_ref(n1);
    mut n2_ref_list := c.get_ref(n2);

    n1_ref_list.val = 10;
    n2_ref_list.val = 20;

    n1_ref_list.next = n2;
    n2_ref_list.next = null;

    mut total := process_list(c, n1);
    os.LogInt(total);
}
