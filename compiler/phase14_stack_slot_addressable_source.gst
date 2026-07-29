// Phase 14.5 positive source marker: an addressable scalar local receives a
// deterministic compiler-owned stack slot with fixed size, alignment, type,
// lifetime, mutability, and no-escape policy.
func main() int {
    mut addressable: int := 51;
    addressable = 52;
    return addressable;
}