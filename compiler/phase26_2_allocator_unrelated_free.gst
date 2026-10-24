import "phase20_protected_access_module.gst" as protected;
func main() int {
 mut ctx := os.Arena.New();
 mut next := os.Arena.New();
 mut value: protected.ProtectedValue[ctx];
 value.value = 7;
 mut owner := protected.acquire(&value, 41);
 next.Free(); protected.consume(owner); ctx.Free();
 return 0;
}
