// Generic Patch 21.13 declaration-admission witness. The declarations are
// intentionally unused: they own no executable MIR, while the scalar function
// still exercises the normal module/import lowering route.
type DeclarationPair struct {
    left: int,
    right: int
}

type DeclarationState enum {
    Ready,
    Done
}

func declaration_add(left: int, right: int) int {
    return left + right;
}
