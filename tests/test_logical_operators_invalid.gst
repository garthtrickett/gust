type Node struct { val: int }

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Node;
    mut ptr := &n;
    
    if n && ptr {
        os.LogInt(1);
    }
}