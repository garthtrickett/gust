// Patch 20.5: a selector field cannot revive a freed canonical identity.
type Phase20FreeHolder struct { arena: Arena }

func main() {
    mut destination := os.Arena.New();
    mut holder: Phase20FreeHolder;
    holder.arena = destination;
    holder.arena.Free();
    mut copied := std.Clone(destination, "freed");
}
