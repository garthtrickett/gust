func main() {
    mut large_str := "ThisIsALargeStringWithManyCharactersToTestThatOurCalculationsAreExtremelyRobustAndPreventAnyPotentialBufferOverflowInTranspiledC";
    mut neg_num := 0 - 2147483648;
    mut max_num := 2147483647;
    mut s := std.Format("String: %s, Neg: %d, Max: %d", large_str, neg_num, max_num);
    os.LogStr(s);
}
