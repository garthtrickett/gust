func main() {
    mut p1 := os.ScratchAlloc(10);
    unsafe {
        *p1 = 42;
        os.LogInt(*p1 as int);
    }
    
    mut p2 := os.ScratchAlloc(20);
    unsafe {
        *p2 = 84;
        os.LogInt(*p2 as int);
    }
    
    os.ScratchReset();
    
    mut p3 := os.ScratchAlloc(10);
    unsafe {
        os.LogInt(*p3 as int);
    }
}