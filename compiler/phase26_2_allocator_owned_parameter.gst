import "phase20_protected_access_module.gst" as protected;
func cannot_free(ctx: Arena, owner: protected.Guard[ctx]) { ctx.Free(); }
func main() int { return 0; }
