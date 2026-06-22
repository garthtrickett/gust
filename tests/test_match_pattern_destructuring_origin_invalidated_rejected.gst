type MyEnum enum {
    VariantA { val: str },
    VariantB
}
func main() {
    mut e: MyEnum;
    e.tag = 0;
    e.VariantA.val = "hello";
    match e {
        VariantA { val } => {
            mut moved_e := move e;
            os.LogStr(val);
        }
        VariantB => {}
    }
}