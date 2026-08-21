// Phase 19.3 canonical branded type naming, inferred arm.
//
// The paired explicit arm differs only by stating the local type annotation.
// Both must construct the same canonical C type name from the resolved brand
// identity, including the namespaced `lib_module__ctx` arena identity.
type NamingHolder[ctx] struct {
    value: int
}

func naming_holder_new(lib_module__ctx: &Arena) NamingHolder[lib_module__ctx] {
    mut holder: NamingHolder[lib_module__ctx];
    holder.value = 19;
    return holder;
}

func naming_probe(lib_module__ctx: &Arena) int {
    mut holder := naming_holder_new(lib_module__ctx);
    return holder.value;
}

func main() int {
    return 0;
}
