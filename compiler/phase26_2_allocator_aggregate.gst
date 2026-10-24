import "phase20_protected_access_module.gst" as protected;
type Holder[ctx] struct { lease: protected.Guard[ctx] }
func main() int {
 mut ctx := os.Arena.New();
 mut next := os.Arena.New();
 mut value: protected.ProtectedValue[ctx];
 value.value = 7;
 mut owner := protected.acquire(&value, 41);
 mut holder: Holder[ctx];
 holder.lease = owner;
 ctx.Free();
 return 0;
}
