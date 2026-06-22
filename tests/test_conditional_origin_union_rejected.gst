func main() {
    mut temp1 := os.MockPayload();
    mut temp2 := os.MockPayload();
    mut view := temp1;
    
    mut cond := 1;
    if cond {
        view = temp1;
    } else {
        view = temp2;
    }
    
    mut moved := move temp2;
    os.LogInt(view[0]); 
}