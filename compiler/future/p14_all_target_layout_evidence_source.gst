// Future positive fixture: representative layout witness runs on every declared host target.
type Phase14TargetWitness struct {
    flag: bool,
    value: int
}
func main() int {
    mut witness: Phase14TargetWitness;
    witness.flag = true;
    witness.value = 14;
    return witness.value;
}